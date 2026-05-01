export enum RayfieldThemes {
    Default = "Default",
    AmberGlow = "AmberGlow",
    Amethyst = "Amethyst",
    Bloom = "Bloom",
    DarkBlue = "DarkBlue",
    Green = "Green",
    Light = "Light",
    Ocean = "Ocean",
    Serenity = "Serenity",
}

export interface RayfieldThemeBuilder {
    TextColor: Color3

    Background: Color3
    Topbar: Color3
    Shadow: Color3

    NotificationBackground: Color3
    NotificationActionsBackground: Color3

    TabBackground: Color3
    TabStroke: Color3
    TabBackgroundSelected: Color3
    TabTextColor: Color3
    SelectedTabTextColor: Color3

    ElementBackground: Color3
    ElementBackgroundHover: Color3
    SecondaryElementBackground: Color3
    ElementStroke: Color3
    SecondaryElementStroke: Color3

    SliderBackground: Color3
    SliderProgress: Color3
    SliderStroke: Color3

    ToggleBackground: Color3
    ToggleEnabled: Color3
    ToggleDisabled: Color3
    ToggleEnabledStroke: Color3
    ToggleDisabledStroke: Color3
    ToggleEnabledOuterStroke: Color3
    ToggleDisabledOuterStroke: Color3

    DropdownSelected: Color3
    DropdownUnselected: Color3

    InputBackground: Color3
    InputStroke: Color3
    PlaceholderColor: Color3
}
