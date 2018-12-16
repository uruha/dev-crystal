require "kemal"
require "multi_auth"
require "base64"

MultiAuth.config("github", "4da9cc8ec5c3db8a4c0b", "b6ccc7b0613741d8031e3305b1d8bac8082ae194")

def self.multi_auth(env)
  provider = env.params.url["provider"]
  redirect_uri = "#{Kemal.config.scheme}://#{env.request.host_with_port.as(String)}/auth/#{provider}/callback"
  MultiAuth.make(provider, redirect_uri)
end

get "/auth/:provider" do |env|
  env.redirect(multi_auth(env).authorize_uri)
end

get "/auth/:provider/callback" do |env|
  user = multi_auth(env).user(env.params.query)
  # p user
  # p user.name
  # p user.email
  # p user.image
  # p user.nickname

  enc_uname = Base64.encode(user.name)
  auth_cookie = HTTP::Cookie.new(
    name: "github_auth",
    value: enc_uname,
    path: "/"
  )
  set_cookie = auth_cookie.to_set_cookie_header()
  p set_cookie
  env.response.headers["Set-Cookie"] = set_cookie
  env.redirect "/chatroom"
end

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

get "/chatroom" do |env|
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

Kemal.config.port = 2240
Kemal.run