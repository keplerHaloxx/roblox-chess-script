// import { ReplicatedStorage } from "@rbxts/services"

// interface Skins {
//     blackSkins: string[]
//     whiteSkins: string[]
// }

// export default function (): Skins {
//     const assets = ReplicatedStorage.FindFirstChild("Assets")!

//     const skins: Skins = {
//         blackSkins: assets
//             .FindFirstChild("Black")!
//             .GetChildren()
//             .map((instance) => instance.Name),
//         whiteSkins: assets
//             .FindFirstChild("White")!
//             .GetChildren()
//             .map((instance) => instance.Name),
//     }

//     return skins
// }
