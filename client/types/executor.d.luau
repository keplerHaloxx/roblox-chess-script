-- Executor-specific declarations for luau-lsp. No application state belongs here.
declare getgenv: () -> unknown
declare getreg: (() -> {unknown})?
-- Arbitrary registry closures have heterogeneous signatures; this is the intentional any boundary.
declare iscclosure: (((...any) -> ...any) -> boolean)?
declare request: (({Url: string, Method: string, Headers: {[string]: string}, Body: string?}) -> unknown)?
declare http_request: typeof(request)
declare queue_on_teleport: ((string) -> ())?
declare queueonteleport: typeof(queue_on_teleport)
declare syn: {request: typeof(request), queue_on_teleport: typeof(queue_on_teleport)}?
declare http: {request: typeof(request)}?
