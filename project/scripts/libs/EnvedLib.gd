class_name EnvedLib
extends RefCounted

const ENV_DEV := "dev"
const ENV_BOX := "box"
const ENV_TEST := "test"
const ENV_PRE := "pre"
const ENV_PROD := "prod"


## 获取当前环境
## 没有设置 APP_ENVED 时，默认 dev
static func tag() -> String:
    var env := OS.get_environment("APP_ENVED")

    if env.is_empty():
        return ENV_DEV

    return env


## 获取环境变量
static func getEnv(key: String, default_value: String = "") -> String:
    var value := OS.get_environment(key)

    if value.is_empty():
        return default_value

    return value


static func isDev() -> bool:
    return tag() == ENV_DEV


static func notDev() -> bool:
    return not isDev()


static func isBox() -> bool:
    return tag() == ENV_BOX


static func notBox() -> bool:
    return not isBox()


static func isTest() -> bool:
    return tag() == ENV_TEST


static func notTest() -> bool:
    return not isTest()


static func isPre() -> bool:
    return tag() == ENV_PRE


static func notPre() -> bool:
    return not isPre()


static func isProd() -> bool:
    return tag() == ENV_PROD


static func notProd() -> bool:
    return not isProd()


static func prod(prod_value, else_value):
    return prod_value if isProd() else else_value

static func isOnline() -> bool:
    return tag() in [ENV_PRE, ENV_PROD]


static func isOffline() -> bool:
    return not isOnline()

static func editor(editor_value = true, else_value = false):
    return editor_value if OS.has_feature("editor") else else_value
