-- Сценарий: только постройка мира (сервер) и снимок для рендера
local mock = ...
mock.startServer()
mock.run(0.5)
local plr = mock.addPlayer("Morty")
mock.run(2)
mock.snapshot("world")
print("parts", mock.partsInWorkspace())
