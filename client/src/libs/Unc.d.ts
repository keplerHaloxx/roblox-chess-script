/* eslint-disable @typescript-eslint/no-explicit-any */

type table = defined[]
type func = (...args: table) => any

// Console
export declare function rconsoleprint(text: string): void
export declare function rconsoleinfo(text: string): void
export declare function rconsoleerr(text: string): void
export declare function rconsoleclear(): void
export declare function rconsolename(title: string): void
export declare function rconsoleinput(): void
export declare function rconsoleclose(): void
export declare function printconsole(
    message: string,
    red: number,
    green: number,
    blue: number
): void

// Enviornment
export declare function getgenv(): { [a: string]: any }
export declare function getrenv(): table
export declare function getreg(): table
export declare function getgc(include_tables?: boolean): table
export declare function getinstances(): table
export declare function getnilinstances(): table
export declare function getloadedmodules(): table
export declare function getconnections(signal: RBXScriptSignal): table
export declare function firesignal(
    signal: RBXScriptSignal,
    ...args: table
): void
export declare function fireclickdetector(
    detector: ClickDetector,
    distance?: number,
    event?: string
): void
export declare function fireproximityprompt(prompt: ProximityPrompt): void
export declare function firetouchinterest(
    totouch: BasePart,
    part: BasePart,
    toggle?: number
): void
export declare function setscriptable(object: Instance, toggle: boolean): void
export declare function gethiddenproperty(
    object: Instance,
    property: string
): void
export declare function sethiddenproperty(
    object: Instance,
    property: string,
    value: any
): void
export declare function setsimulationradius(radius: number): void

// File System
export declare function readfile(path: string): string
export declare function writefile(path: string, content: string): void
export declare function appendfile(path: string, content: string): void
export declare function loadfile(path: string): func
export declare function listfiles(folder: string): table
export declare function isfile(path: string): boolean
export declare function isfolder(path: string): boolean
export declare function makefolder(path: string): void
export declare function delfolder(path: string): void
export declare function delfile(path: string): void

// Hooking
export declare function hookfunction(): (old: func, newfunc: func) => any
export declare function hookmetamethod(
    object: object,
    metamethod: string,
    a1: func
): void
export declare function newcclosure(a1: func): func

// Input
export declare function keypress(keycode: number): void
export declare function keyrelease(keycode: number): void
export declare function mouse1click(): void
export declare function mouse1press(): void
export declare function mouse1release(): void
export declare function mouse2click(): void
export declare function mouse2press(): void
export declare function mouse2release(): void
export declare function mousescroll(number: number): void
export declare function mousemoverel(a1: number, a2: number): void
export declare function mousemoveabs(a1: number, a2: number): void

// Miscellaneous
export declare function setclipboard(content: string): void
export declare function setfflag(flag: string, value: string): void
export declare function getnamecallmethod(): string
export declare function setnamecallmethod(method: string): void
export declare function indentifyexecutor(): LuaTuple<[string, string]>
export declare function setfpscap(cap: number): void
export declare function saveinstance(
    object?: Instance,
    file_path?: string,
    options?: {
        Decompile: boolean
        DecompileTimeout: number
        DecompileIgnore: Services
        NilInstances: boolean
        RemovePlayerCharacters: boolean
        SavePlayers: boolean
        MaxThreads: number
        ShowStatus: boolean
        IgnoreDefaultProps: boolean
        IsolateStarterPlayer: boolean
    }
): void
export declare function decompile(script: Instance): string
export declare function messagebox(
    text: string,
    title: string,
    flag: number
): number
export declare function queue_on_teleport(script: string): undefined

// Reflection
export declare function loadstring(chunk: string, chunk_name?: string): func
export declare function checkcaller(): boolean
export declare function islclosure(a1: func): boolean

// Script
export declare function getsenv(script: LocalScript | ModuleScript): table
export declare function getcallingscript(): Instance
export declare function getscriptclosure(script: Instance): func
export declare function getscripthash(script: Instance): string
export declare function getscriptbytecode(script: Instance): string

// Table
export declare function getrawmetatable(a1: table): table
export declare function setrawmetatable(a1: table, a2: table): boolean
export declare function setreadonly(a1: table, a2: boolean): void
export declare function isreadonly(a1: table): boolean

export declare const cache: {
    replace(x: Instance, y: Instance): void
    invalidate(x: Instance): void
    iscached(x: Instance): boolean
    cloneref(x: Instance): Instance
    compareinstances(x: Instance, y: Instance): boolean
}

export declare const crypt: {
    encrypt(data: string, key: string): string
    decrypt(data: string, key: string): string
    base64: {
        encode(data: string): string
        decode(data: string): string
    }
    hash(data: string): string
    derive(value: string, length: number): string
    random(size: number): string
}

export declare const debug: {
    getconstants(f: func): table
    getconstant(f: func, index: number): any
    setconstant(f: func, index: number, value: number | boolean | string): void
    getupvalues(f: func): table
    getupvalue(f: func | number, index: number): any
    setupvalue(f: func, index: number, value: table): void
    getproto(
        f: func,
        index: number,
        activated?: boolean
    ): LuaTuple<[table, func]>
    setproto(f: func, index: number, replacement: func): void
    getstack(f: func, index: number, value: table): void
    setmetatable(o: table, mt: table): table
    getregistry(): table
    getinfo(f: func): table
}

interface BaseDrawing {
    Visible: boolean
    ZIndex: number
    Transparency: number
    Color: Color3
    Destroy(): void
}

interface LineDrawing extends BaseDrawing {
    From: Vector2
    To: Vector2
    Thickness: number
}

interface TextDrawing extends BaseDrawing {
    Text: string
    TextBounds: Vector2 // Locked property, cannot be set
    Font: Font
    Size: number
    Position: Vector2
    Center: boolean
    Outline: boolean
    OutlineColor: Color3
}

interface ImageDrawing extends BaseDrawing {
    Data: string
    Size: Vector2
    Position: Vector2
    Rounding: number
}

interface CircleDrawing extends BaseDrawing {
    NumSides: number
    Radius: number
    Position: Vector2
    Thickness: number
    Filled: boolean
}

interface SquareDrawing extends BaseDrawing {
    Size: Vector2
    Position: Vector2
    Thickness: number
    Filled: boolean
}

interface QuadDrawing extends BaseDrawing {
    PointA: Vector2
    PointB: Vector2
    PointC: Vector2
    PointD: Vector2
    Thickness: number
    Filled: boolean
}

interface TriangleDrawing extends BaseDrawing {
    PointA: Vector2
    PointB: Vector2
    PointC: Vector2
    Thickness: number
    Filled: boolean
}

type DrawingType =
    | "Line"
    | "Text"
    | "Image"
    | "Circle"
    | "Square"
    | "Quad"
    | "Triangle"

type DrawingTypes<T extends DrawingType> = T extends "Line"
    ? LineDrawing
    : T extends "Text"
      ? TextDrawing
      : T extends "Image"
        ? ImageDrawing
        : T extends "Circle"
          ? CircleDrawing
          : T extends "Square"
            ? SquareDrawing
            : T extends "Quad"
              ? QuadDrawing
              : T extends "Triangle"
                ? TriangleDrawing
                : BaseDrawing

interface DrawingConstructor {
    new <T extends DrawingType>(type: T): DrawingTypes<T>
    Fonts: {
        UI: 0
        System: 1
        Plex: 2
        Monospace: 3
    }
    cleardrawcache(): void
    getrenderproperty(obj: object): any
    isrenderobj(obj: any): boolean
    setrenderobj<T extends BaseDrawing>(
        drawing: T,
        property: string,
        value: any
    ): void
}

export declare const Drawing: DrawingConstructor

interface WebScocket {
    Send(message: string): void
    Close(): void
    OnMessage: RBXScriptSignal
    OnClose: RBXScriptSignal
}

interface WebSocketConstructor {
    connect(url: string): WebScocket
}

export declare const websocket: WebSocketConstructor

export declare const actors: {
    getactors(): string
    run_on_actor(actor: Actor, script: Script): string
    is_parallel(): boolean
}

/**
 * If any of the functions in `funcs` fail then the function will return false
 * @param funcs Any number of parameters that are functions.
 */
export declare function ensure_executor_functions_access(
    ...funcs: ((...args: any[]) => any)[] // able to take in any type of function
): boolean
