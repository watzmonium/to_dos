# frozen string literal
require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require 'tilt/erubis'

configure do
  enable :sessions # sets cookies on client machine
  set :session_secret, 'secret' # in production this 'secret' should be store in env and not just a word.
  # if string is not specified, sinatra will pack a random value, so if you restart the application,
  # the secret changes and any existing sessions will become invalid
end

before do
  @size_error = ' must be at least 1 character and less than 200 characters'
  @unique_error = ' must unique! '
end

helpers do
  def error_for_list_name(list_name, error = 'List name', name = '')
    if !(1..200).cover?(list_name.size)
      error + @size_error
    elsif session[:lists].any? { |list| list[:name] == list_name }
      return if list_name == name

      error + @unique_error + "A list named #{list_name} exits"
    end
  end

  def list_url(index)
    "/lists/#{index}"
  end

  def remaining(todos)
    todos.count { |todo| todo[:completed] }
  end

  def list_class(list)
    'complete' if all_done?(list)
  end

  def all_done?(list)
    return false if size_zero?(list)

    list[:todos].all? { |todo| todo[:completed] == true }
  end

  def size_zero?(list)
    list[:todos].empty?
  end

  def sort_by_done(lists)
    lists.sort_by { |list| all_done?(list) ? 1 : 0 }
  end
end

before do
  session[:lists] ||= []
end

get '/' do
  redirect '/lists', 303
end

# view all lists
get '/lists/?' do
  session[:lists] = sort_by_done(session[:lists])
  @lists = session[:lists]
  erb :lists
end

# create a new list
post '/lists/?' do
  list_name = params[:list_name].strip
  error = error_for_list_name(list_name)
  if error
    session[:failure] = error
    erb :new_list # we don't redirect here to preserve state!!
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = 'New list added successfully' # session is a hash
    redirect '/lists'
  end
end

# render new list form
get '/lists/new/?' do
  erb :new_list
end

get '/lists/:number/?' do
  size = session[:lists].size
  pass if size.zero? || size < params['number'].to_i

  @current_list = session[:lists][params['number'].to_i]
  @current_list[:todos] = @current_list[:todos].sort_by { |todo| todo[:completed] ? 1 : 0 }

  @number = params['number']
  @todos = session[:lists][@number.to_i][:todos]
  pass if @number.to_i > size
  erb :todo_list
end

post '/lists/:number' do
  @number = params['number']
  pass if @number.to_i > session[:lists].size
  list_item = params['list_item'].strip
  error = error_for_list_name(list_item, 'List item')
  if error
    @current_list = session[:lists][params['number'].to_i]
    @name = session[:lists][@number.to_i][:name]
    @todos = session[:lists][@number.to_i][:todos]
    session[:failure] = error
    erb :todo_list # we don't redirect here to preserve state!!
  else
    session[:lists][@number.to_i][:todos] << { name: list_item, completed: false }
    session[:success] = 'New item added successfully' # session is a hash
    redirect "/lists/#{@number}"
    # should redirect invalid numbers
  end
end

post '/lists/:number/complete_all' do
  session[:lists][params['number'].to_i][:todos].each do |todo|
    todo[:completed] = true
  end
  session[:success] = 'All todos marked complete.'
  redirect "/lists/#{params['number']}"
end

post '/lists/:number/todos/:idx' do
  current_list = session[:lists][params['number'].to_i][:todos]
  is_completed = params[:completed] == 'true'
  current_list[params['idx'].to_i][:completed] = is_completed
  session[:success] = 'The todo has been updated.'
  redirect "/lists/#{params['number']}"
end

post '/lists/:number/delete_item' do
  current_list = session[:lists][params['number'].to_i][:todos]
  session[:success] = "#{current_list[params['value'].to_i][:name]} deleted"
  current_list.delete_at(params['value'].to_i)
  redirect "/lists/#{params['number']}"
end

get '/lists/:number/edit/?' do
  @number = params['number']
  @name = session[:lists][@number.to_i][:name]
  erb :edit_list
end

post '/lists/:number/edit/?' do
  list_name = params[:list_name].strip
  @name = session[:lists][@number.to_i][:name]
  @number = params['number']
  error = error_for_list_name(list_name, 'New name', @name)
  if error
    session[:failure] = error
    erb :edit_list # we don't redirect here to preserve state!!
  else
    session[:lists][params['number'].to_i][:name] = list_name
    session[:success] = 'List name updated' # session is a hash
    redirect "/lists/#{params['number']}"
  end
end

post '/lists/:number/delete' do
  session[:success] = "The list '#{session[:lists][params['number'].to_i][:name]}' was deleted."
  session[:lists].delete_at(params['number'].to_i)
  redirect '/lists'
end

not_found do
  redirect '/lists'
end
