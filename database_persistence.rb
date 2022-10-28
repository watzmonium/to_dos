require 'pg'

class DatabasePersistence

  def initialize(logger)
    @db = if Sinatra::Base.production?
            PG.connect(ENV['DATABASE_URL'])
          else
            PG.connect(dbname: "todo_lists")
          end
    @logger = logger
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
      { id: tuple['id'], name: tuple['name'], completed: tuple['completed'] == 't' }
    end
  end

  def query(sql, *params)
    @logger.info("#{sql}: #{params}")
    @db.exec_params(sql, params)
  end

  def add_list(name)
    sql = "INSERT INTO lists (name) VALUES ($1);"
    query(sql, name)
  end

  def add_todo(list_number, todo_name)
    sql = "INSERT INTO todos (list_number, name, completed) VALUES ($1, $2, $3);"
    query(sql, list_number, todo_name, 'false')
  end

  def find_list(id)
    sql = "SELECT * FROM lists WHERE id = $1;"
    result = query(sql, id)
    tuple = result.first
    todos = all_todos(id)
    { id: tuple["id"], name: tuple["name"], todos: todos }
  end

  def update_todo(list_number, index, completed)
    sql = "UPDATE todos SET completed = $1 WHERE id = $2 AND list_number = $3;"
    query(sql, completed, index, list_number)
  end

  def update_list_name(list_id, new_name)
    sql = "UPDATE lists SET name = $1 WHERE id = $2;"
    query(sql, new_name, list_id)
  end

  def mark_todos_done(list_number)
    sql = "UPDATE todos SET completed = true WHERE list_number = $1;"
    query(sql, list_number)
  end

  def delete_list(number)
    sql = "DELETE FROM lists WHERE id = $1"
    query(sql, number)
  end

  def delete_todo(id)
    sql = "DELETE FROM todos WHRE id = $1"
    query(sql, id)
  end
end