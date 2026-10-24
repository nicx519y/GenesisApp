"use client";

import { ChakraProvider, defaultSystem } from "@chakra-ui/react";
import { ThemeProvider } from "next-themes";
import { SiteToaster } from "./toaster";
import type { ReactNode } from "react";

export function Provider({ children }: Readonly<{ children: ReactNode }>) {
  return (
    <ChakraProvider value={defaultSystem}>
      <ThemeProvider attribute="class" defaultTheme="dark" enableSystem={false} disableTransitionOnChange>
        {children}
        <SiteToaster />
      </ThemeProvider>
    </ChakraProvider>
  );
}
