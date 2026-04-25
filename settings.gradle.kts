rootProject.name = "ecommerce-traffic"

include("api-server")
project(":api-server").projectDir = file("modules/api-server")
