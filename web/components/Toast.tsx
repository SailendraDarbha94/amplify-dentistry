import { ToothBrushIcon } from "./icons";

export interface ToastMessage {
  message: string;
  type: string;
}

const Toast = ({ message, type }: ToastMessage) => {
  return (
    <>
      {message && (
        <div className="fixed flex items-center font-pSemiBold z-50 text-lg top-20 right-0 w-80 min-h-14 border-2 border-black p-4 bg-white text-black rounded-xl">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            className="h-10 w-fit"
            viewBox="0 0 128 128"
          >
            <path
              fill="#e65100"
              d="M116.59 13.85L85.34 37.56c-1.37 2.54-.8 4.99.11 6.88c.51 1.06-.12 2.33-1.27 2.6c-5.04 1.19-14.82 2.65-18.98 6.81c0 0-53.81 50.45-56.67 53.09s-4.42 6.41-2.86 10.18c.89 2.16 3.08 4.56 5.91 5.55c5.72 2 8.74.71 14.2-4.75c0 0 55.62-53.7 67.77-65.32c1.1-1.06 2.48-1.75 3.96-2.11s3.6-1.22 5.67-3.3l15.27-15.37c6.43-6.43 1.98-14.12-1.86-17.97"
            />
            <path
              fill="#fb8c00"
              d="M86.53 43.1c4.94 4.94 10.38 1.56 12.27-.33l17.74-17.74c1.89-1.89 4.36-6.86.04-11.18c-2.8-2.8-7.67-2.69-10.79.43L88.06 32.02c-1.9 1.89-4.85 7.75-1.53 11.08"
            />
            <g fill="#69b6c9">
              <path d="m105.78 6.14l-3.16 5.24s7.33 6.41 8.85 7.6c1.13.88 2.13.81 2.94 0s.81-2.13 0-2.94s-8.63-9.9-8.63-9.9" />
              <path d="m91.357 42.02l-10.6-10.6L103.81 8.37l10.6 10.6z" />
              <path d="M84.16 29.84L78.92 33s8.37 7.45 9.89 8.64c1.13.88 2.13.81 2.94 0s.81-2.13 0-2.94c-.81-.82-7.59-8.86-7.59-8.86" />
            </g>
            <path
              fill="#a5ceda"
              d="m105.29 8.54l-3.13 5.23s8.54 7.62 10.07 8.81c1.13.88 2.13.81 2.94 0s.81-2.13 0-2.94s-9.88-11.1-9.88-11.1"
            />
            <path
              fill="#a5ceda"
              d="m102.18 13.04l-4.2 4.2s8.89 7.98 10.42 9.16c1.13.88 2.13.81 2.94 0s.81-2.13 0-2.94s-9.16-10.42-9.16-10.42"
            />
            <path
              fill="#a5ceda"
              d="m98.3 16.82l-4.2 4.2s8.95 8.03 10.47 9.21c1.13.88 2.13.81 2.94 0s.81-2.13 0-2.94s-9.21-10.47-9.21-10.47"
            />
            <path
              fill="#a5ceda"
              d="m93.99 20.17l-4.2 4.2s9.43 8.51 10.95 9.69c1.13.88 2.13.81 2.94 0s.81-2.13 0-2.94s-9.69-10.95-9.69-10.95"
            />
            <path
              fill="#a5ceda"
              d="m90.17 24l-4.2 4.2s9.43 8.51 10.95 9.69c1.13.88 2.13.81 2.94 0s.81-2.13 0-2.94S90.17 24 90.17 24"
            />
            <path
              fill="#a5ceda"
              d="m87.25 28.73l-5.65 3.01s9.97 8.78 11.49 9.97c1.13.88 2.13.81 2.94 0s.81-2.13 0-2.94s-8.78-10.04-8.78-10.04"
            />
            <linearGradient
              id="notoToothbrush0"
              x1="28.935"
              x2="40.103"
              y1="26.259"
              y2="15.091"
              gradientTransform="matrix(-1 0 0 1 128 0)"
              gradientUnits="userSpaceOnUse"
            >
              <stop offset="0" stopColor="#fafafa" />
              <stop offset=".73" stopColor="#eee" />
            </linearGradient>
            <path
              fill="url(#notoToothbrush0)"
              d="M79.33 29.45c.21-.92-.71-2.58.07-3.62c.63-.84 1.15-.69 1.77-.69c.94 0 1.74-.8 1.74-1.74c0-.61.12-1.2.5-1.58s.97-.5 1.58-.5c.94 0 1.74-.8 1.74-1.74c0-.61.12-1.2.5-1.58s.97-.5 1.58-.5c.94 0 1.74-.8 1.74-1.74c0-.61.12-1.2.5-1.58s.97-.5 1.58-.5c.94 0 1.74-.8 1.74-1.74c0-.61.12-1.2.5-1.58s.97-.5 1.58-.5c.94 0 1.74-.8 1.74-1.74c0-.61.13-1.45.85-1.9c1.15-.7 2.38.2 3.29.2c.96 0 2.03-1.55 3.25-.41c1.16 1.08-.03 2.55.07 3.25c.09.62.91 1.97.28 3.17c-.49.93-1.58 1.23-2.19 1.24c-.94 0-1.74.8-1.74 1.74c0 .61-.12 1.2-.5 1.58s-.97.5-1.58.5c-.94 0-1.74.8-1.74 1.74c0 .61-.12 1.2-.5 1.58s-.97.5-1.58.5c-.94 0-1.74.8-1.74 1.74c0 .61-.12 1.2-.5 1.58s-.97.5-1.58.5c-.94 0-1.74.8-1.74 1.74c0 .61-.12 1.2-.5 1.58s-.97.5-1.58.5c-.94 0-1.74.8-1.74 1.74c0 .61-.24 1.49-.8 1.88c-1.79 1.25-3.02-.49-3.88-.17c-.59.22-2.15 1.6-3.29.37c-1.25-1.34.48-2.85.58-3.32"
            />
            <path
              fill="#fb8c00"
              d="M7.11 116.71c4.11 4.11 9.86.76 11.92-1.3c1.6-1.6 53.84-53.37 53.84-53.37c5.11-5.11 6.89-6.5 5.01-9.15s-9.38-2.33-13.54 1.84c0 0-52.56 48.89-54.83 51.16s-5.85 7.37-2.4 10.82"
            />
          </svg>
          {message}
        </div>
      )}
    </>
  );
};

export default Toast;
