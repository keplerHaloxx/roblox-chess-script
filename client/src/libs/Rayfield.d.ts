import { RayfieldThemeBuilder, RayfieldThemes } from "./RayfieldSettings"

//
// Comments came straight from Rayfield documenatation
// https://docs.sirius.menu/rayfield
//
// When Gen2 comes out and at least a significant portion of the documentation has changed
// I will probably rewrite this to look better and have more coherent documentation.
//

interface RayfieldWindowSettings {
    Name: string
    /** Icon in Topbar. Can use Lucide Icons (string) or Roblox Image (number). 0 to use no icon (default). */
    Icon?: string | number
    LoadingTitle?: string
    LoadingSubtitle?: string
    /** Check https://docs.sirius.menu/rayfield/configuration/themes for updated themes */
    Theme?: RayfieldThemes | RayfieldThemeBuilder

    DisableRayfieldPrompts?: boolean
    /** Prevents Rayfield from warning when the script has a version mismatch with the interface. */
    DisableBuildWarnings?: boolean

    ConfigurationSaving?: {
        Enabled: boolean
        FolderName?: string
        FileName: string
    }
    Discord?: {
        Enabled: boolean /** Prompt the user to join your Discord server if their executor supports it. */
        Invite: string /** The Discord invite code, do not include discord.gg/. E.g. discord.gg/ABCD would be ABCD. */
        RememberJoins: boolean /** Set this to false to make them join the discord every time they load it up. */
    }
    KeySystem?: boolean /** Set this to true to use our key system. */
    KeySettings?: {
        Title: string
        Subtitle: string
        /** Use this to tell the user how to get a key. */
        Note: string
        /** It is recommended to use something unique as other scripts using Rayfield may overwrite your key file. */
        FileName: string
        /** The user's key will be saved, but if you change the key, they will be unable to use your script. */
        SaveKey: boolean
        /** If this is true, set Key below to the RAW site you would like Rayfield to get the key from. */
        GrabKeyFromSite: boolean
        /** List of keys that will be accepted by the system, can be RAW file links (pastebin, github etc) or simple strings ("hello","key22"). */
        Key: string[]
    }
}

interface Rayfield {
    Destroy(): void
    Notify(options: {
        Title: string
        Content: string
        Duration?: number
        /** You can either use a Roblox image ID or a Lucide icon name. See [here](https://github.com/latte-soft/lucide-roblox/tree/master/icons/compiled/48px) for the supported icons. */
        Image?: number | string
        Actions?: {
            [index: string]: {
                Name: string
                Callback: () => void
            }
        }
    }): void
    CreateWindow(options: RayfieldWindowSettings): Window
    LoadConfiguration(): void
}

interface Window {
    /**
     * @param image You can either use a Roblox image ID or a Lucide icon name. See [here](https://github.com/latte-soft/lucide-roblox/tree/master/icons/compiled/48px) for the supported icons.
     */
    CreateTab(name: string, image?: number | string): Tab
}

type Paragraph = { Title: string; Content: string }
interface Tab {
    CreateSection(label: string): { Set(label: string): void }
    CreateDivider(): {
        /** Whether the divider's visibility is to be set to true or false. */
        Set(label: boolean): void
    }
    CreateButton(options: Button): Button & { Set(label: string): void }
    CreateToggle(options: Toggle): Toggle & { Set(state: boolean): void }
    CreateColorPicker(
        options: ColorPicker
    ): ColorPicker & { Set(color: Color3): void }
    CreateSlider(options: Slider): Slider & { Set(value: number): void }
    CreateInput(options: Input): Input
    CreateDropdown(options: Dropdown): Dropdown & {
        /**
         * The new selected options
         */
        Set(options: string[]): void
        /**
         * The new list of options available
         */
        Refresh(options: string[]): void
    }
    CreateKeybind(options: Keybind): Keybind & { Set(held?: boolean): void }
    /**
     * @param Icon You can either use a Roblox image ID or a Lucide icon name. See [here](https://github.com/latte-soft/lucide-roblox/tree/master/icons/compiled/48px) for the supported icons.
     */
    CreateLabel(
        Title: string,
        Icon?: number | string,
        Color?: Color3,
        IgnoreTheme?: boolean
    ): { Set(label: string): void }
    CreateParagraph(
        options: Paragraph
    ): Paragraph & { Set(options: Paragraph): void }
}

interface Keybind {
    Name: string
    CurrentKeybind: string
    HoldToInteract: boolean
    /** A flag is the identifier for the configuration file, make sure every element has a different flag if you're using configuration saving to ensure no overlaps */
    Flag: string
    Callback: (bind: string) => void
}

interface Dropdown {
    Name: string
    Options: string[]
    CurrentOption: string[]
    MultipleOptions: boolean
    /** A flag is the identifier for the configuration file, make sure every element has a different flag if you're using configuration saving to ensure no overlaps */
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
    /** A flag is the identifier for the configuration file, make sure every element has a different flag if you're using configuration saving to ensure no overlaps */
    Flag: string
    Callback: (value: number) => void
}

interface ColorPicker {
    Name: string
    Color: Color3
    /** A flag is the identifier for the configuration file, make sure every element has a different flag if you're using configuration saving to ensure no overlaps */
    Flag: string
    Callback: (color: Color3) => void
}

interface Toggle {
    Name: string
    CurrentValue: boolean
    /** A flag is the identifier for the configuration file, make sure every element has a different flag if you're using configuration saving to ensure no overlaps */
    Flag: string
    Callback: (state: boolean) => void
}

interface Button {
    Name: string
    Callback: () => void
}

declare const Rayfield: Rayfield
export = Rayfield
