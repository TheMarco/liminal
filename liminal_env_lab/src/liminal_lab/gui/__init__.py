def launch() -> None:
    try:
        from .app import launch as launch_tk
        launch_tk()
    except ModuleNotFoundError as error:
        if error.name not in {"tkinter", "_tkinter"}:
            raise
        from .web_app import launch_web
        launch_web()

__all__ = ["launch"]
