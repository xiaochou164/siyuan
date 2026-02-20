type IpcListener = (...args: any[]) => void;

const noop = () => undefined;

export const ipcRenderer = {
    send: noop,
    on: (_channel: string, _listener: IpcListener) => noop,
    once: (_channel: string, _listener: IpcListener) => noop,
    removeListener: (_channel: string, _listener: IpcListener) => noop,
    removeAllListeners: (_channel?: string) => noop,
    invoke: async (_channel: string, _args?: any) => undefined,
};

export const shell = {
    openExternal: (url: string) => {
        try {
            window.open(url, "_blank", "noopener,noreferrer");
            return Promise.resolve();
        } catch (err) {
            return Promise.reject(err);
        }
    },
};

export const webFrame = {
    setZoomFactor: noop,
    clearCache: noop,
};

export const clipboard = {
    read: (_format?: string) => "",
    readText: () => "",
    writeText: (_text: string) => undefined,
};

export const webUtils = {
    getPathForFile: (file: File & { path?: string }) => file.path || file.name || "",
};

export type FileFilter = { name: string; extensions: string[] };
