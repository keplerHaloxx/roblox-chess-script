--!strict
-- Public stable Gen2 API, reviewed against https://docs.sirius.menu/rayfield-gen2 (2026-10-01).
-- Canonical camelCase properties are used; the runtime also accepts PascalCase aliases.
-- Preview-only heartbeat and fallbackFont settings are intentionally excluded.
-- This module exports types only. It does not load Rayfield or create UI.

export type Icon = string | number
export type ThemeName = "default" | "cobalt" | "ember" | "amethyst" | "frost" | "rose"
export type Gradient = ColorSequence | Color3
export type Key = EnumItem | string
export type Translations = { [string]: { [string]: string } }
export type Translator = (source: string, localeId: string) -> string?

--- Partial custom palettes inherit defaults at creation and overlay the current palette on ChangeTheme.
--- Gradient fields accept a solid Color3. See /rayfield-gen2/themes.
export type Theme = {
	--- Window rounding.
	CornerRoundness: UDim?,
	--- Window fill gradient.
	WindowColor: Gradient?,
	--- Surface shadow color.
	ShadowColor: Color3?,
	--- Animate the background gradient.
	LiveAnimation: boolean?,
	--- Pill rounding.
	PillCornerRadius: UDim?,
	--- Control rounding.
	ElementCornerRadius: UDim?,
	--- Surface border color.
	SurfaceStroke: Color3?,
	--- Heading font.
	TitleFont: Font?,
	--- Body font.
	Font: Font?,
	--- Body text color.
	ContentColor: Color3?,
	--- Title text color.
	TitlingColor: Color3?,
	--- Hovered text color.
	ElementTextHoverColor: Color3?,
	--- Window action icons.
	ActionColor: Color3?,
	--- Tab foreground.
	TabColor: Color3?,
	--- Tab fill.
	TabBackground: Gradient?,
	--- Tab border.
	TabStroke: Gradient?,
	--- Control border.
	ElementStroke: Color3?,
	--- Control fill.
	ElementGradient: Gradient?,
	--- Border sheen.
	ElementStrokeGradient: Gradient?,
	--- Fill transparency.
	ElementTransparency: number?,
	--- Border transparency.
	ElementStrokeTransparency: number?,
	--- Hovered border color.
	ElementStrokeHover: Color3?,
	--- Hovered border transparency.
	ElementStrokeHoverTransparency: number?,
	--- Stat surface.
	StatBackground: Color3?,
	--- Active control color.
	AccentColor: Color3?,
	--- Accent border.
	AccentStroke: Color3?,
	--- Glow transparency; 1 hides it.
	AccentGlow: number?,
	--- Track color.
	SliderBackground: Color3?,
	--- Hovered track.
	SliderBackgroundHover: Color3?,
	--- Filled track.
	SliderProgress: Gradient?,
	--- Track border.
	SliderStroke: Color3?,
	--- Drag handle.
	SliderHandle: Color3?,
	--- Switch track.
	ToggleTrack: Color3?,
	--- Switch transparency.
	ToggleTrackTransparency: number?,
	--- Inactive knob color.
	ToggleKnobOff: Color3?,
	--- Inactive knob transparency.
	ToggleKnobOffTransparency: number?,
	--- Darken light switch tracks.
	DarkToggleOverlay: boolean?,
	--- Selected choice color.
	DropdownHighlight: Color3?,
	--- Input field color.
	FieldBackground: Color3?,
	--- Input transparency.
	FieldTransparency: number?,
	--- Input glow.
	FieldGlow: Color3?,
	--- Placeholder foreground.
	PlaceholderColor: Color3?,
	--- Neutral dialog button.
	NeutralButton: Color3?,
	--- Hovered neutral button.
	NeutralButtonHover: Color3?,
	--- Neutral button border.
	NeutralButtonStroke: Color3?,
	--- Error fill.
	ErrorColor: Color3?,
	--- Error border.
	ErrorStrokeColor: Color3?,
}

--- Stable explicit flags survive label changes; forgetState excludes an element from persistence.
export type SavedProps = { flag: string?, forgetState: boolean? }
--- Shared labels, secondary help text, and asset icons. No properties are required unless noted.
export type ElementProps = { name: string?, description: string?, icon: Icon? }
--- Every element can be repositioned within its containing tab.
export type Orderable = {
	--- Reposition at the given index.
	MoveTo: (self: Orderable, index: number) -> (),
	--- Move to the beginning.
	MoveToTop: (self: Orderable) -> (),
	--- Move to the end.
	MoveToBottom: (self: Orderable) -> (),
	--- Move one position earlier.
	MoveUp: (self: Orderable) -> (),
	--- Move one position later.
	MoveDown: (self: Orderable) -> (),
}
--- Interactive controls can block user input; Set remains available from code.
export type Lockable = {
	--- Block user interaction; an optional reason replaces help text.
	Lock: (self: Lockable, reason: string?) -> (),
	--- Restore user interaction and original help text.
	Unlock: (self: Lockable) -> (),
	--- Report whether interaction is blocked.
	IsLocked: (self: Lockable) -> boolean,
}
--- Set updates the control and invokes its callback unless skipCallback is true.
export type ValueHandle<T> = Orderable & Lockable & {
	value: T,
	Set: (self: ValueHandle<T>, value: T, skipCallback: boolean?) -> (),
}
--- A click invokes callback without arguments. See /elements/buttons.
export type ButtonProps = {
	--- Display label or heading.
	name: string?,
	--- Supporting help text.
	description: string?,
	--- Asset identifier or supported content URI.
	icon: Icon?,
	callback: (() -> ())?,
}
export type Button = Orderable & Lockable
--- Boolean control; CreateSwitch is an equivalent constructor. See /elements/toggles.
export type ToggleProps = {
	--- Display label or heading.
	name: string?,
	--- Supporting help text.
	description: string?,
	--- Asset identifier or supported content URI.
	icon: Icon?,

	--- Stable configuration key; omission derives it from the label.
	flag: string?,
	--- Exclude this control from saved state.
	forgetState: boolean?,
	value: boolean?,
	callback: ((value: boolean) -> ())?,
}
export type Toggle = ValueHandle<boolean>
--- range is {minimum, maximum}; increment defaults to 1. Bounds remain reachable.
--- dragging becomes false on the final callback. See /elements/sliders.
export type SliderProps = {
	--- Display label or heading.
	name: string?,
	--- Supporting help text.
	description: string?,
	--- Asset identifier or supported content URI.
	icon: Icon?,

	--- Stable configuration key; omission derives it from the label.
	flag: string?,
	--- Exclude this control from saved state.
	forgetState: boolean?,

	--- Minimum and maximum bounds in a two-entry array.
	range: { number }?,
	--- Snap interval measured from the minimum; default 1.
	increment: number?,
	value: number?,
	--- Text after the numeric value.
	suffix: string?,
	--- Hide the slider label for compact layouts.
	minimal: boolean?,
	callback: ((value: number, dragging: boolean) -> ())?,
}
export type Slider = ValueHandle<number>
--- Single-selection callbacks receive a string; multiple selection receives a copied array.
--- The handle's value is always an array. See /elements/dropdowns.
export type SingleDropdownProps = {
	--- Display label or heading.
	name: string?,
	--- Supporting help text.
	description: string?,
	--- Asset identifier or supported content URI.
	icon: Icon?,

	--- Stable configuration key; omission derives it from the label.
	flag: string?,
	--- Exclude this control from saved state.
	forgetState: boolean?,

	--- Available choices or dialog actions, depending on the control.
	options: { string }?,
	value: (string | { string })?,
	--- Enable multiple selected choices.
	multiSelect: false?,
	--- Text shown when the selection or field is empty.
	placeholder: string?,
	callback: ((selected: string) -> ())?,
}
export type MultiDropdownProps = {
	--- Display label or heading.
	name: string?,
	--- Supporting help text.
	description: string?,
	--- Asset identifier or supported content URI.
	icon: Icon?,

	--- Stable configuration key; omission derives it from the label.
	flag: string?,
	--- Exclude this control from saved state.
	forgetState: boolean?,

	--- Available choices or dialog actions, depending on the control.
	options: { string }?,
	value: { string }?,
	--- Enable multiple selected choices.
	multiSelect: true,
	--- Text shown when the selection or field is empty.
	placeholder: string?,
	callback: ((selected: { string }) -> ())?,
}
export type DropdownProps = SingleDropdownProps | MultiDropdownProps
export type Dropdown = Orderable & Lockable & {
	value: { string },
	Set: (self: Dropdown, value: string | { string }, skipCallback: boolean?) -> (),
	--- Replaces choices and drops obsolete selections; affected selections trigger the callback.
	Refresh: (self: Dropdown, options: { string }) -> (),
	Add: (self: Dropdown, option: string) -> (),
	Remove: (self: Dropdown, option: string) -> (),
}
--- Commits text on enter or focus loss. numeric validates input; clearOnFocus empties it on focus.
--- Inputs belong directly to tabs. See /elements/inputs.
export type InputProps = {
	--- Display label or heading.
	name: string?,
	--- Supporting help text.
	description: string?,
	--- Asset identifier or supported content URI.
	icon: Icon?,

	--- Stable configuration key; omission derives it from the label.
	flag: string?,
	--- Exclude this control from saved state.
	forgetState: boolean?,

	value: string?,
	--- Text shown when the selection or field is empty.
	placeholder: string?,
	--- Validate numeric input and reject malformed commits.
	numeric: boolean?,
	--- Empty the input when editing begins.
	clearOnFocus: boolean?,
	callback: ((text: string) -> ())?,
}
export type Input = ValueHandle<string>
--- Normal bindings call back with a key; hold bindings report activation/release as booleans.
--- Set invokes onChanged, not the press callback. Tabs only. See /elements/keybinds.
export type PressKeybindProps = {
	--- Display label or heading.
	name: string?,
	--- Supporting help text.
	description: string?,
	--- Asset identifier or supported content URI.
	icon: Icon?,

	--- Stable configuration key; omission derives it from the label.
	flag: string?,
	--- Exclude this control from saved state.
	forgetState: boolean?,

	value: Key?,
	--- Emit booleans for sustained press/release instead of key events.
	hold: false?,
	--- Hold duration before activation, in seconds; default 0.2.
	holdThreshold: number?,
	callback: ((key: EnumItem) -> ())?,
	--- Called when the binding changes, rather than when the key is pressed.
	onChanged: ((key: EnumItem) -> ())?,
}
export type HoldKeybindProps = {
	--- Display label or heading.
	name: string?,
	--- Supporting help text.
	description: string?,
	--- Asset identifier or supported content URI.
	icon: Icon?,

	--- Stable configuration key; omission derives it from the label.
	flag: string?,
	--- Exclude this control from saved state.
	forgetState: boolean?,

	value: Key?,
	--- Emit booleans for sustained press/release instead of key events.
	hold: true,
	--- Hold duration before activation, in seconds; default 0.2.
	holdThreshold: number?,
	callback: ((held: boolean) -> ())?,
	--- Called when the binding changes, rather than when the key is pressed.
	onChanged: ((key: EnumItem) -> ())?,
}
export type KeybindProps = PressKeybindProps | HoldKeybindProps
export type Keybind = Orderable & Lockable & {
	value: EnumItem,
	Set: (self: Keybind, value: Key, skipChanged: boolean?) -> (),
}
--- Accepts Color3 or hex input; alpha is opacity from 0 to 1 and saves with the color.
--- Tabs only. See /elements/color-pickers.
export type ColorPickerProps = {
	--- Display label or heading.
	name: string?,
	--- Supporting help text.
	description: string?,
	--- Asset identifier or supported content URI.
	icon: Icon?,

	--- Stable configuration key; omission derives it from the label.
	flag: string?,
	--- Exclude this control from saved state.
	forgetState: boolean?,

	color: (Color3 | string)?,
	--- Opacity in the inclusive range 0 to 1.
	alpha: number?,
	callback: ((color: Color3, alpha: number) -> ())?,
}
export type ColorPicker = Orderable & Lockable & {
	value: Color3,
	--- Opacity in the inclusive range 0 to 1.
	alpha: number,
	Set: (self: ColorPicker, color: Color3 | string, skipCallback: boolean?) -> (),
	--- Update opacity; true suppresses the callback.
	SetAlpha: (self: ColorPicker, alpha: number, skipCallback: boolean?) -> (),
}
--- Unsaved numeric display with animated deltas. Row groups force compact presentation.
--- Compact cards omit description. See /elements/stats.
export type StatProps = {
	--- Display label or heading.
	name: string?,
	--- Supporting help text.
	description: string?,
	--- Asset identifier or supported content URI.
	icon: Icon?,

	value: number?,
	--- Text before the numeric value.
	prefix: string?,
	--- Text after the numeric value.
	suffix: string?,
	--- Choose value or delta for compact stat cards.
	display: ("value" | "change")?,
	--- Use a compact stat card; row groups enforce this.
	compact: boolean?,
	--- Render a relative percentage or an absolute delta.
	changeMode: ("percentage" | "absolute")?,
	--- Compare against the previous or initial value.
	changeBaseline: ("previous" | "initial")?,
	--- Animate numeric transitions; enabled by default.
	numberEasing: boolean?,
}
export type Stat = Orderable & {
	value: number,
	Set: (self: Stat, value: number) -> (),
	--- Reset the stat comparison baseline.
	ResetBaseline: (self: Stat, value: number?) -> (),
}
--- Unsaved progress display. steps enables segments; indeterminate animates unknown work.
--- text overrides format; Set ends the indeterminate animation. See /elements/progress.
export type ProgressProps = {
	--- Display label or heading.
	name: string?,
	--- Supporting help text.
	description: string?,
	--- Asset identifier or supported content URI.
	icon: Icon?,

	--- Minimum and maximum bounds in a two-entry array.
	range: { number }?,
	value: number?,
	--- At least two segments; without an explicit range, counts from 0 to steps.
	steps: number?,
	text: string?,
	--- Custom progress readout; ignored when fixed text is supplied.
	format: ((value: number, minimum: number, maximum: number) -> string)?,
	--- Display progress text; defaults to true.
	showValue: boolean?,
	--- Animate unknown progress until Set supplies a value.
	indeterminate: boolean?,
}
export type Progress = Orderable & {
	value: number,
	Set: (self: Progress, value: number) -> (),
	Get: (self: Progress) -> number,
	--- Returns the fraction of the range, from 0 to 1.
	GetPercentage: (self: Progress) -> number,
	--- Replace progress bounds and clamp the current value.
	SetRange: (self: Progress, minimum: number, maximum: number) -> (),
	--- Change text; nil clears a progress readout override.
	SetText: (self: Progress, text: string?) -> (),
	--- Switch the progress animation on or off.
	SetIndeterminate: (self: Progress, state: boolean) -> (),
}
--- Scrollable fixed-height text; follow scrolls appended lines into view; maxLines bounds memory.
--- code aliases text. See /elements/console.
export type ConsoleProps =
	ElementProps
	& { text: string?, code: string?, height: number?, follow: boolean?, maxLines: number? }
export type Console = Orderable & {
	Set: (self: Console, text: string) -> (),
	--- Append console content, respecting its line limit.
	Append: (self: Console, line: string) -> (),
	--- Empty console content.
	Clear: (self: Console) -> (),
	Get: (self: Console) -> string,
	--- False means clipboard support is unavailable.
	Copy: (self: Console) -> boolean,
	--- Change console height.
	SetHeight: (self: Console, height: number) -> (),
}
--- Independent heading/body; empty strings remove either. Unsaved. See /elements/text.
export type TextProps = {
	--- Display label or heading.
	name: string?,
	--- Supporting help text.
	description: string?,
	--- Asset identifier or supported content URI.
	icon: Icon?,
	text: string?,
}
export type Text = Orderable & {
	--- Display label or heading.
	name: string,
	text: string,
	Set: (self: Text, text: string) -> (),
	--- Replace the text heading; an empty string removes it.
	SetTitle: (self: Text, title: string) -> (),
}
--- Optional caption; line=false leaves whitespace only. See /elements/dividers.
export type DividerProps = {
	--- Display label or heading.
	name: string?,
	--- Supporting help text.
	description: string?,
	--- Asset identifier or supported content URI.
	icon: Icon?,
	text: string?,
	spacing: number?,
	line: boolean?,
}
export type Divider = Orderable & { text: string, Set: (self: Divider, text: string) -> () }
export type SectionProps = ElementProps
export type Section = Orderable
export type SidebarSection = { Remove: (self: SidebarSection) -> () }
export type GroupProps = { direction: ("row" | "column" | "horizontal" | "vertical")? }
--- Groups nest. Row-only layout rejects full-width children; nullable handles model that rejection.
--- Inputs, keybinds and color pickers are intentionally absent. See /tabs.
export type Group = {
	CreateGroup: (self: Group, props: GroupProps?) -> Group,
	CreateSection: (self: Group, props: SectionProps) -> Section?,
	CreateButton: (self: Group, props: ButtonProps) -> Button,
	CreateToggle: (self: Group, props: ToggleProps) -> Toggle,
	CreateSwitch: (self: Group, props: ToggleProps) -> Toggle,
	CreateSlider: (self: Group, props: SliderProps) -> Slider,
	CreateStat: (self: Group, props: StatProps) -> Stat,
	CreateDropdown: (self: Group, props: DropdownProps) -> Dropdown?,
	CreateText: (self: Group, props: TextProps) -> Text?,
	CreateDivider: (self: Group, props: DividerProps?) -> Divider?,
}
--- At least one of name or icon must be supplied. The first visible tab opens initially.
export type TabProps = { name: string?, icon: Icon? }
export type Tab = {
	--- Activate this tab; true skips the transition.
	Select: (self: Tab, noAnimation: boolean?) -> (),
	--- Deactivate this tab; true skips the transition.
	Deselect: (self: Tab, noAnimation: boolean?) -> (),
	Remove: (self: Tab) -> (),
	CreateGroup: (self: Tab, props: GroupProps?) -> Group,
	CreateSection: (self: Tab, props: SectionProps) -> Section,
	CreateButton: (self: Tab, props: ButtonProps) -> Button,
	CreateToggle: (self: Tab, props: ToggleProps) -> Toggle,
	CreateSwitch: (self: Tab, props: ToggleProps) -> Toggle,
	CreateSlider: (self: Tab, props: SliderProps) -> Slider,
	CreateDropdown: (self: Tab, props: DropdownProps) -> Dropdown,
	CreateInput: (self: Tab, props: InputProps) -> Input,
	CreateKeybind: (self: Tab, props: KeybindProps) -> Keybind,
	CreateColorPicker: (self: Tab, props: ColorPickerProps) -> ColorPicker,
	CreateStat: (self: Tab, props: StatProps) -> Stat,
	CreateProgress: (self: Tab, props: ProgressProps) -> Progress,
	CreateConsole: (self: Tab, props: ConsoleProps) -> Console,
	CreateText: (self: Tab, props: TextProps) -> Text,
	CreateDivider: (self: Tab, props: DividerProps?) -> Divider,
}
--- Corner notification; duration defaults to a text-length estimate. Hover pauses dismissal.
--- See /notifications.
export type NotificationProps = { title: string?, content: string?, icon: Icon?, duration: number? }
--- Compact top/bottom message. avatar is a Roblox user ID; minWidth is capped at 320.
export type ToastProps = {
	title: string?,
	subtitle: string?,
	--- Place the secondary toast line first.
	subtitleAbove: boolean?,
	--- Asset ID or supported content URI; nil/0/empty hides it.
	icon: Icon?,
	--- Roblox user ID to render as a headshot.
	avatar: number?,
	--- Toast minimum width, capped at 320 pixels.
	minWidth: number?,
	--- Display time in seconds; omission uses a text-based estimate.
	duration: number?,
	--- Top or bottom screen placement for a toast.
	position: ("Top" | "Bottom")?,
}
--- Dialog buttons run callbacks before closing. boxes replaces paragraph content. See /popups.
export type PopupOption = { text: string, style: ("neutral" | "primary" | "danger")?, callback: (() -> ())? }
export type PopupBox = { title: string, description: string?, icon: Icon? }
export type PopupProps = {
	title: string?,
	subtitle: string?,
	--- Asset ID or supported content URI; nil/0/empty hides it.
	icon: Icon?,
	content: string?,
	--- Cards displayed instead of a paragraph.
	boxes: { PopupBox }?,
	--- Available choices or dialog actions, depending on the control.
	options: { PopupOption }?,
	--- Allow Escape or backdrop dismissal; defaults to true.
	dismissable: boolean?,
}
export type Popup = { Close: (self: Popup) -> () }
--- Title-bar badge, requiring text or icon. title aliases text; order controls sorting. See /tags.
export type TagProps = { text: string?, title: string?, icon: Icon?, color: Color3?, order: number? }
export type Tag = {
	--- Change tag fill.
	SetColor: (self: Tag, color: Color3) -> (),
	--- Change text; nil clears a progress readout override.
	SetText: (self: Tag, text: string) -> (),
	--- Change the tag icon.
	SetIcon: (self: Tag, icon: Icon) -> (),
	Set: (self: Tag, props: TagProps) -> (),
	Remove: (self: Tag) -> (),
}
--- State restores through callbacks, including controls created after initial load. See /saving.
export type Configuration = { autoSave: boolean?, autoLoad: boolean?, fileName: string?, customFolder: string? }
--- Window options for the stable loader. See /windows and /localization.
--- Translations map locale IDs to English-source keys; translator may return nil to use tables.
export type WindowProps = {
	--- Display label or heading.
	name: string?,
	subtitle: string?,
	theme: (ThemeName | Theme)?,
	--- Asset ID or supported content URI; nil/0/empty hides it.
	icon: Icon?,
	--- Place tabs in the left rail instead of across the top.
	sidebarLayout: boolean?,
	--- Secondary profile text in the sidebar.
	profile: string?,
	--- Caption on the collapsed window pill.
	showName: string?,
	--- Collapsed pill icon.
	showIcon: Icon?,
	--- Use an icon-only collapsed pill.
	showIconOnly: boolean?,
	--- Enable configuration persistence.
	configuration: Configuration?,
	--- Pin a language; omission follows the player locale.
	locale: string?,
	--- Locale-indexed tables keyed by English source strings.
	translations: Translations?,
	--- Resolve before translation tables; return nil to fall through.
	translator: Translator?,
}
--- Dynamic flag values vary by control. Read as unknown and narrow before use.
export type Window = {
	--- True once the window has been destroyed.
	unloaded: boolean,
	--- Live values keyed by persistence flag; assignments also update controls.
	Flags: { [string]: unknown },
	CreateTab: (self: Window, props: TabProps) -> Tab,
	--- Sidebar headings are unavailable when sidebarLayout is false.
	CreateSection: (self: Window, props: SectionProps) -> SidebarSection?,
	CreateTag: (self: Window, props: TagProps) -> Tag,
	--- Update sidebar profile text; nil removes it.
	SetProfile: (self: Window, text: string?) -> (),
	--- Display a dismissible corner card.
	Notify: (self: Window, props: NotificationProps) -> (),
	--- Display a compact transient message.
	Toast: (self: Window, props: ToastProps) -> (),
	--- Open a modal and return its close handle.
	Popup: (self: Window, props: PopupProps) -> Popup,
	--- Reveal the window.
	Show: (self: Window) -> (),
	--- Collapse to its pill.
	Hide: (self: Window) -> (),
	--- Toggle window visibility.
	ToggleHide: (self: Window) -> (),
	--- Toggle between content and title bar.
	ToggleMinimise: (self: Window) -> (),
	--- Select a tab by name or handle.
	Navigate: (self: Window, tab: Tab | string) -> (),
	--- Destroys the UI and sets unloaded; the handle cannot be reused afterwards.
	Unload: (self: Window) -> (),
	ChangeTheme: (self: Window, theme: ThemeName | Theme) -> (),
	--- Apply a locale to visible copy.
	SetLocale: (self: Window, id: string) -> (),
	--- Replace the resolver; reapply the locale to refresh text.
	SetTranslator: (self: Window, translator: Translator) -> (),
	--- Merge additional language tables.
	RegisterTranslations: (self: Window, translations: Translations) -> (),
	--- Save to the default or named configuration; report success.
	Save: (self: Window, name: string?) -> boolean,
	--- Load the default or named configuration through control callbacks.
	Load: (self: Window, name: string?) -> boolean,
	--- Enumerate named configurations.
	ListConfigs: (self: Window) -> { string },
	--- Remove a named configuration; report success.
	DeleteConfig: (self: Window, name: string) -> boolean,
	--- Return the configuration directory and file path.
	GetPath: (self: Window) -> (string, string),
	Get: (self: Window, flag: string) -> unknown,
	--- Applies the value and calls its callback; false indicates an unknown flag.
	Set: (self: Window, flag: string, value: unknown) -> boolean,
}
export type Library = { CreateWindow: (self: Library, props: WindowProps) -> Window }
--- Optional library environment setting, applied before loading. See /secure-mode.
export type Environment = { RAYFIELD_SECURE: boolean? }
return {}
