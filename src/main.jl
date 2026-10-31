println("Loading modules...")

include("web_server.jl")
using .WebServer

port = parse(Int, get(ENV, "PORT", "8080"))
start_server(port)
