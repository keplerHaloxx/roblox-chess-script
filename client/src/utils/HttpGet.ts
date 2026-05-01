function HttpGet(url: string): string {
    return (
        game as unknown as DataModel & { HttpGet(url: string): string }
    ).HttpGet(url)
}

export default HttpGet
