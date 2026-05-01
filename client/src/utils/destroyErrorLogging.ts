import { ReplicatedStorage } from '@rbxts/services'

export default () => {
    const clienterror =
        ReplicatedStorage.FindFirstChild("Connections")!.FindFirstChild(
            "ReportClientError"
        )
    if (clienterror) clienterror.Destroy()
}
