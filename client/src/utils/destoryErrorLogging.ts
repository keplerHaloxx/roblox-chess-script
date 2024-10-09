import { ReplicatedStorage } from '@rbxts/services'

export = () => {
    const clienterror =
        ReplicatedStorage.FindFirstChild("Connections")!.FindFirstChild(
            "ReportClientError"
        )
    if (clienterror) clienterror.Destroy()
}
