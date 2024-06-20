Options:Default("trace")

Tasks:clean()

Tasks:minify "minify" {
    input = "build/sgps.lua",
    output = "build/sgps.min.lua",
}

Tasks:require "main" {
    startup = "sgps.lua",
    output = "build/sgps.lua",
}

Tasks:Task "build" {"clean", "minify"} :Description("Main build task")

Tasks:Default "main"