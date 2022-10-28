# frozen string literal
require 'sinatra'
require 'sinatra/content_for'
require 'tilt/erubis'

require_relative 'database_persistence'
configure do
  enable :sessions # sets cookies on client machine
  set :session_secret, 'secret' # in production this 'secret' should be store in env and not just a word.
  # if string is not specified, sinatra will pack a random value, so if you restart the application,
  # the secret changes and any existing sessions will become invalid
  set :erb, :escape_html => true
end

configure (:development) do
  require 'sinatra/reloader' if development?
  also_reload 'database_persistence.rb'
end

helpers do
  def error_for_list_name(list_name, error = 'List name', name = '')
    if !(1..200).cover?(list_name.size)
      error + @size_error
    elsif @storage.all_lists.any? { |list| list[:name] == list_name }
      return if list_name == name

      return if error == 'List item'

      error + @unique_error + "A list named #{list_name} exits"
    end
  end

  def list_url(index)
    "/lists/#{index}"
  end

  def remaining(todos)
    todos.count { |todo| todo[:completed] }
  end

  def size_zero?(list)
    list[:todos].empty?
  end

  def list_class(list)
    'complete' if all_done?(list)
  end

  def all_done?(list)
    return false if size_zero?(list)

    list[:todos].all? { |todo| todo[:completed] == true }
  end

  def sort_by_done(lists)
    lists.sort_by { |list| all_done?(list) ? 1 : 0 }
  end

  def failure(error)
    @session[:failure] = error
  end

  def failure?
    @session[:failure] != nil
  end

  def delete_failure
    @session.delete(:failure)
  end

  def success?
    @session[:success] != nil
  end

  def delete_success
    @session.delete(:success)
  end

  # def next_id(object)    
  #   highest = 0
  #   object.each { |list| highest = list[:id] if list[:id] > highest }
  #   highest + 1
  # end

  def disconnect
    @db.close
  end
end

before do
  @storage = DatabasePersistence.new(logger)
  @session = session
  @size_error = ' must be at least 1 character and less than 200 characters'
  @unique_error = ' must unique! '
end

after do
  @storage.disconnect
end

get '/' do
  redirect '/lists', 303
end

# view all lists
get '/lists/?' do
  @lists = sort_by_done(@storage.all_lists)
  erb :lists
end

# create a new list
post '/lists/?' do
  list_name = params[:list_name].strip
  error = error_for_list_name(list_name)
  if error
    @session[:failure] = error
    erb :new_list # we don't redirect here to preserve state!!
  else
    @storage.add_list(list_name)
    @session[:success] = 'New list added successfully' # session is a hash
    redirect '/lists'
  end
end

# render new list form
get '/lists/new/?' do
  erb :new_list
end

get '/lists/:number/?' do
  @number = params['number'].to_i
  @current_list = @storage.find_list(@number)
  if @current_list
    @name = @current_list[:name]
    @current_list[:todos] = @current_list[:todos].sort_by { |todo| todo[:completed] ? 1 : 0 }
    @todos = @current_list[:todos]
    erb :todo_list
  else
    @session[:failure] = "List #{@number} not in database!"
    redirect '/lists'
  end
end

post '/lists/:number' do
  @number = params['number'].to_i
  @current_list = @storage.find_list(@number)
  list_item = params['list_item'].strip
  error = error_for_list_name(list_item, 'List item')
  if error
    @name = @current_list[:name]
    @todos = @current_list[:todos]
    @session[:failure] = error
    erb :todo_list # we don't redirect here to preserve state!!
  else
    @storage.add_todo(@number, list_item)
    @session[:success] = 'New item added successfully' # session is a hash
    redirect "/lists/#{@number}"
    # should redirect invalid numbers
  end
end

post '/lists/:number/complete_all' do
  @number = params['number'].to_i
  @storage.mark_todos_done(@number)
  @session[:success] = 'All todos marked complete.'
  redirect "/lists/#{@number}"
end

post '/lists/:number/todos/:idx' do
  list_number = params['number'].to_i
  is_completed = params[:completed] == 'true'
  index = params['idx'].to_i
  @storage.update_todo(list_number, index, is_completed)
  @session[:success] = 'The todo has been updated.'
  redirect "/lists/#{list_number}"
end

post '/lists/:number/delete_item' do
  todo_id = params['value']
  @storage.delete_todo(list_id, todo_id)
  name = params['name']
  # the rack spec env header prepends with HTTP
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    #inside ajax
    #status 204 no content
    status 204
  else
    @session[:success] = "#{name} deleted"
    redirect "/lists/#{params['number']}"
  end
end

get '/lists/:number/edit/?' do
  @number = params['number'].to_i
  @current_list = @storage.find_list(@number)
  @name = @current_list[:name]
  erb :edit_list
end

post '/lists/:number/edit/?' do
  list_name = params[:list_name].strip
  @number = params['number'].to_i
  @current_list = @storage.find_list(@number)
  @name = @current_list[:name]
  error = error_for_list_name(list_name, 'New name', @name)
  if error
    @session[:failure] = error
    erb :edit_list # we don't redirect here to preserve state!!
  else
    @storage.update_list_name(@number, list_name)
    @session[:success] = 'List name updated' # session is a hash
    redirect "/lists/#{@number}"
  end
end

post '/lists/:number/delete' do
  @number = params['number'].to_i
  @current_list = @storage.find_list(@number)
  @name = @current_list[:name]  
  @storage.delete_list(@number)
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    '/lists' # sinatra defaults to 200
  else
    @session[:success] = "The list '#{@name}' was deleted."
    redirect '/lists'
  end
end

not_found do
  redirect '/lists'
end
