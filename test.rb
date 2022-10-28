require 'pg'

class DatabasePersistence

  def initialize
    @db = PG.connect(dbname: 'todo_lists')
    #@logger = logger
  end

  def all_lists
    sql = "SELECT * FROM lists;"
    result = query(sql)
    result.map do |tuple|
      id = tuple['id']
      todos = all_todos(id)
      { id: tuple["id"], name: tuple["name"], todos: todos }
    end
  end

  def all_todos(id)
    sql = "SELECT * FROM todos WHERE list_number = $1;"
    result = query(sql, id)
    result.map do |tuple|
      complete = tuple['completed'] == 't' ? true : false
      { id: tuple['id'], name: tuple['name'], completed: complete}
    end
  end

  def query(sql, *params)
    #@logger.info("#{sql}: #{params}")
    @db.exec_params(sql, params)
  end

  def <<(object)
    # @session[:lists] << object
  end

  def failure(error)
    # @session[:failure] = error
  end

  def failure?
    # @session[:failure] != nil
  end

  def delete_failure
    # @session.delete(:failure)
  end

  def success(message)
    # @session[:success] = message
  end

  def success?
    # @session[:success] != nil
  end

  def delete_success
    # @session.delete(:success)
  end

  def find_list(id)
    sql = "SELECT * FROM lists WHERE id = $1;"
    result = query(sql, id)
    tuple = result.first
    { id: tuple["id"], name: tuple["name"], todos: [] }
  end



  def update_todo(list_number, index, completed)
    # list = self.find_list(list_number)
    # list[:todos].each do |todo|
    #   todo[:completed] = completed if todo[:id] == index
    # end
  end

  def mark_todos_done(list_number)
    # list = self.find_list(list_number)
    # list[:todos].each do |todo|
    #   todo[:completed] = true
    # end
  end

  def delete_list(number)
    # @session[:lists].reject! { |list| list[:id] == number }
  end
end

p DatabasePersistence.new.all_lists