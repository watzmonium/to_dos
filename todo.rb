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
  set :erb, :escape_html => true
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

  def next_todo_id(list)
    highest = 0
    list.each { |todos| highest = todos[:id] if todos[:id] > highest }
    highest + 1
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
    id = next_todo_id(session[:lists])
    session[:lists] << { name: list_name, todos: [], id: id }
    session[:success] = 'New list added successfully' # session is a hash
    redirect '/lists'
  end
end

# render new list form
get '/lists/new/?' do
  erb :new_list
end

get '/lists/:number/?' do
  @number = params['number'].to_i
  @current_list = session[:lists].find { |list| list[:id] == @number }
  pass unless @current_list

  @name = @current_list[:name]
  @current_list[:todos] = @current_list[:todos].sort_by { |todo| todo[:completed] ? 1 : 0 }
  @todos = @current_list[:todos]

  erb :todo_list
end

post '/lists/:number' do
  @number = params['number'].to_i
  @current_list = session[:lists].find { |list| list[:id] == @number }

  list_item = params['list_item'].strip
  error = error_for_list_name(list_item, 'List item')
  if error
    @name = @current_list[:name]
    @todos = @current_list[:todos]
    session[:failure] = error
    erb :todo_list # we don't redirect here to preserve state!!
  else
    id = next_todo_id(@current_list[:todos])
    @current_list[:todos] << { id: id, name: list_item, completed: false }
    session[:success] = 'New item added successfully' # session is a hash
    redirect "/lists/#{@number}"
    # should redirect invalid numbers
  end
end

post '/lists/:number/complete_all' do
  @number = params['number'].to_i
  @current_list = session[:lists].find { |list| list[:id] == @number }
  @current_list[:todos].each do |todo|
    todo[:completed] = true
  end
  session[:success] = 'All todos marked complete.'
  redirect "/lists/#{@number}"
end

post '/lists/:number/todos/:idx' do
  @number = params['number'].to_i
  @current_list = session[:lists].find { |list| list[:id] == @number }

  is_completed = params[:completed] == 'true'
  @current_list[:todos].each do |todo|
    todo[:completed] = is_completed if todo[:id] == params['idx'].to_i
  end
  session[:success] = 'The todo has been updated.'
  redirect "/lists/#{@number}"
end

post '/lists/:number/delete_item' do
  @number = params['number'].to_i
  @current_list = session[:lists].find { |list| list[:id] == @number }
  current_item = ''
  del_idx = 0
  @current_list[:todos].each_with_index do |todo, idx|
    if todo[:id] == params['value'].to_i
      del_idx = idx
      current_item = todo[:name]
    end
  end
  @current_list[:todos].delete_at(del_idx)
  # the rack spec env header prepends with HTTP
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    #inside ajax
    #status 204 no content
    status 204
  else
    session[:success] = "#{current_item} deleted"
    redirect "/lists/#{params['number']}"
  end
end

get '/lists/:number/edit/?' do
  @number = params['number'].to_i
  @current_list = session[:lists].find { |list| list[:id] == @number }
  @name = @current_list[:name]
  erb :edit_list
end

post '/lists/:number/edit/?' do
  list_name = params[:list_name].strip
  @number = params['number'].to_i
  @current_list = session[:lists].find { |list| list[:id] == @number }
  @name = @current_list[:name]
  error = error_for_list_name(list_name, 'New name', @name)
  if error
    session[:failure] = error
    erb :edit_list # we don't redirect here to preserve state!!
  else
    @current_list[:name] = list_name
    session[:success] = 'List name updated' # session is a hash
    redirect "/lists/#{@number}"
  end
end

post '/lists/:number/delete' do
  @number = params['number'].to_i
  @current_list = session[:lists].find { |list| list[:id] == @number }
  @name = @current_list[:name]  
  session[:lists].reject! { |list| list[:id] == @number}
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    '/lists' # sinatra defaults to 200
  else
    session[:success] = "The list '#{list_name}' was deleted."
    redirect '/lists'
  end
end

not_found do
  redirect '/lists'
end
