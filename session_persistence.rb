class SessionPersistence

  def initialize(session)
    @session = session
    @session[:lists] ||= []
  end

  def all_lists
    @session[:lists]
  end

  def <<(object)
    @session[:lists] << object
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

  def success(message)
    @session[:success] = message
  end

  def success?
    @session[:success] != nil
  end

  def delete_success
    @session.delete(:success)
  end

  def list_class(list)
    'complete' if all_done?(list)
  end

  def size_zero?(list)
    list[:todos].empty?
  end

  def remaining(todos)
    todos.count { |todo| todo[:completed] }
  end

  def find_list(id)
    @session[:lists].find { |list| list[:id] == id }
  end

  def sort_by_done
    @session[:lists] = @session[:lists].sort_by { |list| all_done?(list) ? 1 : 0 }
  end

  def all_done?(list)
    return false if size_zero?(list)

    list[:todos].all? { |todo| todo[:completed] == true }
  end

  def each
    @session[:lists].each do |list|
      yield(list)
    end
  end

  def any?
    @session[:lists].each do |list|
      return true if yield(list)
    end
    false
  end

  def update_todo(list_number, index, completed)
    list = self.find_list(list_number)
    list[:todos].each do |todo|
      todo[:completed] = completed if todo[:id] == index
    end
  end

  def mark_todos_done(list_number)
    list = self.find_list(list_number)
    list[:todos].each do |todo|
      todo[:completed] = true
    end
  end

  def delete_list(number)
    @session[:lists].reject! { |list| list[:id] == number }
  end
end