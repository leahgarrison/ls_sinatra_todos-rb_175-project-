require 'sinatra'
require 'sinatra/reloader'# if development?
require 'tilt/erubis'
require 'sinatra/content_for'

configure do
  enable :sessions
  set :session_secret, 'secret'
end

configure do
  set :erb, :escape_html => true
end

before do
  session[:lists] ||= []  # structure of session[:lists]; array of hashes [{:name=>"list 1", :number=>0, :todos=>[]}, {:name=>"list 2", :number=>1, :todos=>[]}]
end

def load_list(id)
   list = session[:lists].find{ |list| list[:id] == id }
  return list if list

  session[:error] = "The specified list was not found."
  redirect "/lists"
end

# helper methods here are intended to be used in the view templates, leave other methods separate
helpers do 
  def list_complete?(list)
    todos_count(list) > 0 && todos_remaining_count(list) == 0
  end 
  
  def list_class(list)
    "complete" if list_complete?(list)
  end
  def todos_count(list)
    list[:todos].size
  end
  
  def todos_remaining_count(list)
    list[:todos].count { |todo| todo[:completed] == false }
  end
  
  def sort_lists(lists, &block) 
    incomplete_lists = {}
    complete_lists = {}
    
    complete_lists, incomplete_lists = lists.partition { |list| list_complete?(list) }
    # lists.each_with_index do |list, index|
    #   if list_complete?(list)
    #     complete_lists[list] = index
    #   else 
    #     incomplete_lists[list] = index
    #   end 
    # end 
    
    incomplete_lists.each(&block)
    complete_lists.each(&block)
  
    # lists.sort_by { |list| list_complete?(list) ? 1 : 0 }
  end 
  
  def sort_todos(todos, &block)
    incomplete_todos= {}
    complete_todos = {}
    # todos.each_with_index do |todo, index|
    #   if todo[:completed]
    #     complete_todos[todo] = index
    #   else 
    #     incomplete_todos[todo] = index
    #   end 
    # end 
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed] }
    # incomplete_todos.each { |todo| yield todo, todos.index(todo) }   # iterating through  a hash with the key value pairs as differnt lists; the index is the index and key of each list
    # complete_todos.each { |todo| yield todo, todos.index(todo) } 
    incomplete_todos.each(&block)
    complete_todos.each(&block)
  
  # def sort_todos_by_completed(list)
  #   list[:todos].sort_by { |todo| todo[:completed] ? 1 : 0 }
  # end
    
  end
end 

  
  def next_todo_id(list)
    max = list.map { |todo| todo[:id] }.max || 0
    max + 1
  end
  
  def next_list_id(lists)
    max = lists.map { |list| list[:id] }.max || 0
    max + 1
  end

get '/' do
  help = '/lists'
  redirect '/lists'
end

# view all of the lists
get '/lists' do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# render the new list form
get '/lists/new' do
  # session[:lists] << { name: 'New List', todos: [] }
  # redirect '/lists'
  erb :new_list, layout: :layout
end

# return an error message if name is invalid. return nil if name is valid
def error_for_list_name(name)
  # if list_name.size >= 1 && list_name.size <= 100
  if !(1..100).cover? name.size
    'List name must be between 1 and 100 characters.'
  elsif session[:lists].any? { |list| list[:name] == name }
    'List name must be unique.'
  end
end

# create a new list, and validate list length

# goal is for these blocks to do one thing as well as methods
post '/lists' do
  list_name = params[:list_name].strip
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    id = next_list_id(session[:lists])
    # list_number = session[:lists].size
    session[:lists] << { id: id, name: list_name, todos: [] }
    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end

# goal page to display a single list
get '/lists/:number' do
  @list_number = params[:number].to_i
  @list = load_list(@list_number)
  erb :list, layout: :layout
end


# edit  an existing todo list
get '/lists/:number/edit' do
    list_id = params[:number].to_i
  @current_list = load_list(list_id)
  erb :edit_list, layout: :layout
end

# update an existing todolist
post '/lists/:number' do
  @list_number = params[:number].to_i
  @current_list = load_list(@list_number) #list id is the list index in the array
  list_name = params[:new_list_name].strip
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
   @current_list[:name] = list_name
    session[:success] = 'The list name has been changed.'
    redirect '/lists'
  end
end

# delete a list
# delete the list, go back to main lists page.
post '/lists/:number/delete' do   #use post, modifying data, flash success when deleted?
    list_number = params[:number].to_i
    @list = load_list(list_number)
    list_name = @list[:name]
# if deleted?
  # session[:lists].delete_if { |list| list[:id] == list_number }
  session[:lists].delete(@list)
  #session[:lists].reject! { |list| list[:id] == list_number }
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    return "/lists"
  elsif !session[:lists].include?(@list)
    session[:success] = "The list named '#{list_name}' was successfully deleted"
  else  session[:error] = "Error. List was not deleted."
  end 
  
  redirect '/lists'  # goes to the get request version
end


# def get_list(key)
#   session[:lists].select { |list| list[:number] == list_id }[0]
# end

# delete a list button from the user's session, on the edit page.



  # get method; things that are safe to happen all the time
  # post requests - like modifying data

  
  
# add a new todo to a list
post '/lists/:list_number/todos' do
  @list_number = params[:list_number].to_i
  new_item = params[:todo].strip
  @list =  load_list(@list_number)
  
  
  error = error_for_todo(new_item)
  
  if error
    session[:error] = error
    erb :list, layout: :layout
  else 
    id = next_todo_id(@list[:todos])
    @list[:todos] << {id: id, name: new_item, completed: false}
    session[:success] = "The todo item was added"
    redirect "/lists/#{@list_number}"
  end 

end

def error_for_todo(name)
   if !(1..100).cover? name.size
    'List name must be between 1 and 100 characters.'
  end
end 

# delete a todo item from list
post '/lists/:list_number/todos/:todo_number/delete' do
  list_number = params[:list_number].to_i
   @list = load_list(list_number)
  

  todo_number = params[:todo_number].to_i
  @list[:todos].delete_if { |todo| todo[:id] == todo_number }
  #@list.delete(@todo)
  #@list[:todos].reject! { |todo| todo[:id] == todo_number }
  # @list[:todos].delete_at(todo_number)
  session[:success] = "The todo was successfully deleted"
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    return status 204
  else
    redirect "/lists/#{list_number}"
  # else session[:error] = "Error. '#{@todo[:name]}' todo was not deleted."
  end

end

# update the status of a todo
post '/lists/:list_number/todos/:todo_number/toggle' do
  list_number = params[:list_number].to_i
  @list = load_list(list_number)
  
  todo_number = params[:todo_number].to_i
  
  @todo = @list[:todos].find { |todo| todo[:id] == todo_number }
  if params[:completed] == "true"
      @todo[:completed] = true
  else  @todo[:completed] = false
  end
  session[:success] = "The todo has been updated"
  
  redirect "/lists/#{list_number}"
  
end

# mark all todos in a list as completed
post '/lists/:number/complete_all' do
  list_number = params[:number].to_i
  @list = load_list(list_number)
  @list[:todos].each do |todo|
    todo[:completed] = true
  end
  session[:success] = "All todos have been completed"

  redirect "/lists/#{list_number}"
end


# post '/lists/:list_number/todos/:todo_number/:state=false' do
#   list_number = params[:list_number].to_i
#   @list = session[:lists][list_number]
#   todo_number = params[:todo_number].to_i
#   @todo = @list[:todos][todo_number]
#   todo_toggle_value = params[:completed]
#   @todo[:completed] = false
  
#   session[:success] = "The todo has been updated"
  
#   redirect "/lists/#{list_number}"
  
# end

