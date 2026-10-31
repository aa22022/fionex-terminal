println("Loading modules...")

include("web_server.jl")
using .WebServer

start_server(8080)
