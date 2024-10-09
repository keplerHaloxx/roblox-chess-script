function rprint(
    s: unknown,
    func?: (...args: unknown[]) => void,
    l = 100,
    i = ""
): number {
    const printmethod = func || print

    // Default item limit and indent string
    if (l < 1) {
        printmethod("ERROR: Item limit reached.")
        return l - 1
    }

    const ts = typeOf(s)

    // If it's not a table, print the value
    if (ts !== "table") {
        printmethod(i, ts, s)
        return l - 1
    }

    // Print "table"
    printmethod(i, ts)

    // Loop through the table and recursively print keys and values
    for (const [k, v] of pairs(s as Record<string | number | symbol, unknown>)) {
        l = rprint(v, printmethod, l, `${i}\t[${tostring(k)}]`)
        if (l < 0) break
    }

    return l
}

export = rprint