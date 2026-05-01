// Chess columns are labelled a–h (ASCII 97–104).
// The board is mirrored: 'a' → x=8, 'h' → x=1.
const columnCharToX = (char: string): number => 9 - (string.byte(char)[0]! - 96)

export default (result: string): LuaTuple<[number, number, number, number]> => {
    const chars = result.split("")

    const x1 = columnCharToX(chars[0]!)
    const y1 = tonumber(chars[1])!
    const x2 = columnCharToX(chars[2]!)
    const y2 = tonumber(chars[3])!

    return $tuple(x1, y1, x2, y2)
}
