"use client";
import Toast, { ToastMessage } from "@/components/Toast";
import React, { createContext, useEffect, useState } from "react";

export const ToastContext = createContext({
  toast: (params: ToastMessage) => Promise.resolve(),
});

const ToastContextProvider = ({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) => {
  const [isVisible, setIsVisible] = useState<boolean>(true);
  const [toastMessage, setToastMessage] = useState<string>("");
  const [toastType, setToastType] = useState<string>("");

  const toast = async (params: ToastMessage) => {
    await setToastMessage(params.message);
    await setToastType(params.type);
    await console.log(params);
    await setIsVisible(true);
  };

  useEffect(() => {
    // Set a timer for 2 seconds
    const timer = setTimeout(() => {
      setIsVisible(false);
    }, 2000);

    // Clean up the timer when the component unmounts
    return () => clearTimeout(timer);
  }, [isVisible]);

  return (
    <div className="z-50">
      <ToastContext.Provider value={{ toast }}>
        {isVisible ? <Toast type={toastType} message={toastMessage} /> : null}
        {children}
      </ToastContext.Provider>
    </div>
  );
};

export default ToastContextProvider;
