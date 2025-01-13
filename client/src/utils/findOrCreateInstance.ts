function findOrCreateInstance(
    parent: Instance,
    child: string,
    instance: keyof CreatableInstances
): Instance | undefined {
    if (parent.FindFirstChild(child)) return parent

    const new_instance = new Instance(instance)
    new_instance.Name = child
    new_instance.Parent = parent

    return new_instance
}

export = findOrCreateInstance
