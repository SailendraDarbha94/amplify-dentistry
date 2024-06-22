export interface ToastMessage {
  message: string;
  type: string;
}

const Toast = ({ message, type }: ToastMessage) => {
  return (
    <>
      {message && (
        <div className="fixed font-pSemiBold z-50 text-lg top-20 right-0 w-80 min-h-14 border-2 border-black p-4 bg-white text-black rounded-xl">
          {message}
        </div>
      )}
    </>
  );
};

export default Toast;
