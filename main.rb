require 'date'
require 'json'
require 'sequel'
require 'sinatra'
require 'sinatra-websocket'


DB = Sequel.sqlite('db.sqlite3')

DB.create_table :graphs do
  primary_key :id
  String :name, unique: true, null: false
  String :description
  DateTime :created_at
end unless DB.table_exists?(:graphs)

class Graph < Sequel::Model(DB[:graphs])
end

DB.create_table :data do
  String :key, null: false
  foreign_key :graph_id, :graphs
  Float :x, null: false
  Float :y, null: false
  DateTime :created_at
end unless DB.table_exists?(:data)

class Datum < Sequel::Model(DB[:data])
  def to_json(*args)
    {key: key, x: x, y: y}.to_json
  end
end


set :server, :thin
set :sockets, {}


get '/' do
  redirect '/graphs'
end

get '/graphs' do
  @graphs = Graph.all
  erb :graphs
end


post '/graphs' do
  name = params[:name]
  description = params[:description]
  Graph.insert(name: name, description: description)

  status 200
  body ''
end


get '/graphs/:id' do
  id = params[:id]
  @graph = Graph.find(id: id) || Graph.find(name: id)
  unless @graph
    status 404
    body ''
    return
  end

  unless request.websocket?
    status 200
    body File.read('views/chart.html')
    return
  end

  # websocket
  request.websocket do |ws|
    ws.onopen do
      settings.sockets[@graph.id] ||= []
      settings.sockets[@graph.id] << ws
      data = Datum.where(graph_id: @graph.id).to_a
      ws.send(data.to_json)
    end

    ws.onclose do
      settings.sockets[@graph.id].delete(ws)
    end
  end
end


put '/graphs/:id' do
  # TODO(change configuration)
  status 200
  body ''
end


delete '/graphs/:id' do
  id = params[:id]
  graph = Graph.find(id: id) || Graph.find(name: id)
  unless graph
    status 404
    body ''
    return
  end

  Datum.where(graph_id: graph.id).delete
  graph.delete

  status 200
  body ''
end

post '/graphs/:id/data' do
  id = params[:id]
  key = params[:key]
  x = params[:x].to_f
  y = params[:y].to_f

  @graph = Graph.find(id: id) || Graph.find(name: id)
  unless @graph
    status 404
    body ''
    return
  end
  Datum.insert(graph_id: @graph.id, key: key, x: x, y: y)

  sockets = settings.sockets[@graph.id] || []
  sockets.each do |socket|
    socket.send([{key: key, x: x, y: y}].to_json)
  end

  status 200
  body ''
end


delete '/graphs/:id/data' do
  id = params[:id]
  graph = Graph.find(id: id) || Graph.find(name: id)
  unless graph
    status 404
    body ''
    return
  end
  Datum.where(graph_id: graph.id).delete

  status 200
  body ''
end
