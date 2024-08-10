"use client";
import { createContext, useState, useEffect } from "react";
import * as React from "react";
import { NextUIProvider } from "@nextui-org/system";
import { useRouter } from "next/navigation";
import { ThemeProvider as NextThemesProvider } from "next-themes";
import { ThemeProviderProps } from "next-themes/dist/types";
import Toast from "@/components/Toast";

export interface ProvidersProps {
  children: React.ReactNode;
  themeProps?: ThemeProviderProps;
}

export interface ToastMessage {
  message: string;
  type: string;
}

export const ToastContext = createContext({
  toast: (params: ToastMessage) => Promise.resolve(),
});

export function Providers({ children, themeProps }: ProvidersProps) {
  const router = useRouter();
  const [isVisible, setIsVisible] = useState<boolean>(true);
  const [toastMessage, setToastMessage] = useState<string>("");
  const [toastType, setToastType] = useState<string>("");

  const toast = async (params: ToastMessage) => {
    await setToastMessage(params.message);
    await setToastType(params.type);
    //await console.log(params);
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
    <NextUIProvider navigate={router.push}>
      <NextThemesProvider {...themeProps}>
        <ToastContext.Provider value={{ toast }}>
          {isVisible ? <Toast type={toastType} message={toastMessage} /> : null}
          {children}
        </ToastContext.Provider>
      </NextThemesProvider>
    </NextUIProvider>
  );
}
