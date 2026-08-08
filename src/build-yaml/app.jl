using Oxygen
using HTTP
using JSON3

# 引入我们刚才分离的后端处理模块
include("YamlBuilder.jl")
using .YamlBuilder

# Save locally by default. Set GRIDDINGMACHINE_YAML_DIR to choose another directory.
const SAVE_DIR = abspath(get(ENV, "GRIDDINGMACHINE_YAML_DIR", joinpath(pwd(), "yaml-output")))
mkpath(SAVE_DIR)

# 路由：返回独立的 index.html 文件
@get "/" function(req::HTTP.Request)
    # 动态读取 html 文件，这样你修改 index.html 后，直接刷新浏览器就能看到效果，无需重启后端服务！
    html_content = read(joinpath(@__DIR__, "index.html"), String)
    return html(html_content)
end

@post "/preview" function(req::HTTP.Request)
    payload = JSON3.read(req.body)
    # 调用 YamlBuilder 模块里的方法
    yaml_str = build_yaml_string(payload)
    return Dict("status" => "success", "yaml" => yaml_str)
end

@post "/save" function(req::HTTP.Request)
    payload = JSON3.read(req.body)
    tag = String(payload.TAG)
    occursin(r"^[A-Za-z0-9_.-]+$", tag) || return HTTP.Response(400, "TAG contains unsupported filename characters")
    yaml_str = build_yaml_string(payload)

    filename = "$(tag).yaml"
    filepath = joinpath(SAVE_DIR, filename)
    write(filepath, yaml_str)

    return Dict(
        "status" => "success", 
        "message" => "文件已严格按格式保存至: $filepath",
        "yaml" => yaml_str
    )
end

println("🚀 服务启动中，稍后请在浏览器访问 http://127.0.0.1:8080")
serve(host="127.0.0.1", port=8080)
