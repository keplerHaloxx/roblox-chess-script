export = (result: string): LuaTuple<[number, number, number, number]> => {
    const chars = result.split("")
    const charsMap = new Map<string, string>()
    chars.forEach((c, i) => {
        charsMap.set(tostring(i), c)
    })

    const x1 = 9 - (string.byte(charsMap.get("0")!)[0] - 96)
    const y1 = tonumber(charsMap.get("1")!)!

    const x2 = 9 - (string.byte(charsMap.get("2")!)[0] - 96)
    const y2 = tonumber(charsMap.get("3")!)!

    return [x1, y1, x2, y2] as LuaTuple<[number, number, number, number]>
}
