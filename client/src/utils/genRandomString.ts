/**
 * Generates a random string of size `length` consisting of numbers and upper and lowercase letters
 * */ 
function genRandomString(length: number): string {
    let result = ""
    const chars =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    const charactersLength = chars.size()
    for (let i = 0; i < length; i++) {
        const randomIndex = math.random(1, chars.size())
        result += chars.sub(randomIndex, randomIndex)
    }
    return result
}

export = genRandomString
