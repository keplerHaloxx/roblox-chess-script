function findOrCreateInstance(
    parent: Instance,
    child: string,
    instance: keyof CreatableInstances
): Instance | undefined {
    if (!parent.FindFirstChild(child)) {
        const folder = new Instance(instance)
        folder.Name = child
        folder.Parent = parent
    } else {
        return parent
    }
}

export = findOrCreateInstance
