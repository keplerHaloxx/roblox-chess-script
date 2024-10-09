interface Rayfield {
    Destroy(): void
    Notify(options: {
        Title: string
        Content: string
        Duration?: number
        Image?: number
        Actions?: {
            [index: string]: {
                Name: string
                Callback: () => void
            }
        }
    }): void
    CreateWindow(options: {
        Name: string
        LoadingTitle: string
        LoadingSubtitle: string
        ConfigurationSaving?: {
            Enabled: boolean
            FolderName?: string
            FileName: string
        }
        Discord?: {
            Enabled: boolean
            Invite: string
            RememberJoins: boolean
        }
        KeySystem?: boolean
        KeySettings?: {
            Title: string
            Subtitle: string
            Note: string
            FileName: string
            SaveKey: boolean
            GrabKeyFromSite: boolean
            Key: string[]
        }
    }): Window
}

interface Window {
    CreateTab(name: string, image?: number): Tab
}

type Paragraph = { Title: string; Content: string }
interface Tab {
    CreateSection(label: string): { Set(label: string): void }
    CreateButton(options: Button): Button & { Set(label: string): void }
    CreateToggle(options: Toggle): Toggle & { Set(state: boolean): void }
    CreateColorPicker(
        options: ColorPicker
    ): ColorPicker & { Set(color: Color3): void }
    CreateSlider(options: Slider): Slider & { Set(value: number): void }
    CreateInput(options: Input): Input
    CreateDropdown(
        options: Dropdown
    ): Dropdown & { Set(options: string[]): void }
    CreateKeybind(options: Keybind): Keybind & { Set(held?: boolean): void }
    CreateLabel(text: string): { Set(label: string): void }
    CreateParagraph(
        options: Paragraph
    ): Paragraph & { Set(options: Paragraph): void }
}

interface Keybind {
    Name: string
    CurrentKeybind: string
    HoldToInteract: boolean
    Flag: string
    Callback: (bind: string) => void
}

interface Dropdown {
    Name: string
    Options: string[]
    CurrentOption: string[]
    MultipleOptions: boolean
    Flag: string
    Callback: (options: string[]) => void
}

interface Input {
    Name: string
    PlaceholderText: string
    RemoveTextAfterFocusLost: boolean
    Callback: (text: string) => void
}

interface Slider {
    Name: string
    Range: [number, number]
    Increment: number
    Suffix: string
    CurrentValue: number
    Flag: string
    Callback: (value: number) => void
}

interface ColorPicker {
    Name: string
    Color: Color3
    Flag: string
    Callback: (color: Color3) => void
}

interface Toggle {
    Name: string
    CurrentValue: boolean
    Flag: string
    Callback: (state: boolean) => void
}

interface Button {
    Name: string
    Callback: () => void
}

declare const Rayfield: Rayfield
export = Rayfield
