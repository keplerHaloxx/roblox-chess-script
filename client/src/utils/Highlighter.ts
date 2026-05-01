import { Workspace } from "@rbxts/services"
import CoreGui from "@utils/coreGui"

export interface HighlightOptions {
    Name?: string
    FillColor?: Color3
    DepthMode?: Enum.HighlightDepthMode
    FillTransparency?: number
    OutlineColor?: Color3
    OutlineTransparency?: number
    Parent?: Instance
}

const STORAGE_NAME = "HighlightStorage"
const DEFAULT_FILL_COLOR = Color3.fromRGB(59, 235, 223)
const DEFAULT_OUTLINE_COLOR = Color3.fromRGB(255, 255, 255)

export class Highlighter {
    public readonly highlight: Highlight

    public constructor(target: Instance, options?: HighlightOptions) {
        const storage = Highlighter.getOrCreateStorage()

        const alreadyHighlighted = storage
            .GetChildren()
            .some((child) => child.IsA("Highlight") && child.Adornee === target)

        if (alreadyHighlighted) {
            warn(
                `Attempted to highlight an already-highlighted instance: ${target.Name}`
            )
        }

        const highlight = new Instance("Highlight")
        highlight.Name = options?.Name ?? "Highlight"
        highlight.FillColor = options?.FillColor ?? DEFAULT_FILL_COLOR
        highlight.DepthMode =
            options?.DepthMode ?? Enum.HighlightDepthMode.AlwaysOnTop
        highlight.FillTransparency = options?.FillTransparency ?? 0.5
        highlight.OutlineColor = options?.OutlineColor ?? DEFAULT_OUTLINE_COLOR
        highlight.OutlineTransparency = options?.OutlineTransparency ?? 0
        highlight.Parent = options?.Parent ?? storage
        highlight.Adornee = target

        this.highlight = highlight
    }

    /**
     * Destroys the underlying Highlight instance.
     */
    public destroy(): void {
        this.highlight.Destroy()
    }

    /**
     * Removes every Highlight from the board, pieces, and the CoreGui cache.
     */
    public static destroyAll(): void {
        const destroyHighlightsIn = (parent: Instance | undefined) =>
            parent?.GetDescendants().forEach((child) => {
                if (child.IsA("Highlight")) child.Destroy()
            })

        destroyHighlightsIn(Workspace.FindFirstChild("Board"))
        destroyHighlightsIn(Workspace.FindFirstChild("Pieces"))

        CoreGui.FindFirstChild(STORAGE_NAME)
            ?.GetDescendants()
            .forEach((child) => child.Destroy())
    }

    private static getOrCreateStorage(): Instance {
        const existing = CoreGui.FindFirstChild(STORAGE_NAME)
        if (existing) return existing

        const folder = new Instance("Folder")
        folder.Name = STORAGE_NAME
        folder.Parent = CoreGui
        return folder
    }
}
