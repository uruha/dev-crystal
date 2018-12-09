require "kemal"

["/", "/articles"].each do |path|
  get path do |env|
    title = "index page"
    articles = [
      {"id" => 1, "title" => "記事 01", "body" => "記事01の内容だよ"},
      {"id" => 3, "title" => "title_3", "body" => "body_2"},
      {"id" => 2, "title" => "title_2", "body" => "body_3"}
    ]

    render "src/views/index.ecr", "src/views/layouts/layout.ecr"
  end
end

get "/hello/:name" do |env|
  title = "greeting"
  name = env.params.url["name"]
  render "src/views/hello.ecr", "src/views/layouts/layout.ecr"
end

SOCKETS = [] of HTTP::WebSocket

get "/chatroom" do |socket|
  title = "Chat"
  render "src/views/chatroom.ecr"
end

ws "/chat" do |socket|
  SOCKETS << socket

  socket.on_message do |message|
    SOCKETS.each { |socket| socket.send message }
  end

  socket.on_close do
    SOCKETS.delete socket
  end
end

static_headers do |response, filepath, filestat|
  if filepath =~ /\.html$/
    response.headers.add("Access-Control-Allow-Origin", "*")
  end

  response.headers.add("Content-Size", filestat.size.to_s)
end

Kemal.run
