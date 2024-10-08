"use client";
import {
  Navbar as NextUINavbar,
  NavbarContent,
  NavbarMenu,
  NavbarMenuToggle,
  NavbarItem,
  NavbarMenuItem,
  NavbarBrand,
} from "@nextui-org/navbar";
import { Button } from "@nextui-org/button";
import { Link } from "@nextui-org/link";
import { Input } from "@nextui-org/input";
import { link as linkStyles } from "@nextui-org/theme";
import NextLink from "next/link";
import clsx from "clsx";
import { usePathname, useRouter } from "next/navigation";
import { getAuth, signOut } from "firebase/auth";
import { useContext } from "react";
import Image from "next/image";
import { siteConfig } from "@/config/site";
import { ThemeSwitch } from "@/components/theme-switch";
import {
  GithubIcon,
  SearchIcon,
  PortfolioIcon,
  LogoutIcon,
  ToothBrushIcon,
} from "@/components/icons";
import app from "@/config/firebase";
import { ToastContext } from "@/app/providers";

export const Navbar = () => {
  const searchInput = (
    <Input
      aria-label="Search"
      classNames={{
        inputWrapper: "bg-default-100",
        input: "text-sm",
      }}
      // endContent={
      //   <Kbd className="hidden lg:inline-block" keys={["command"]}>
      //     K
      //   </Kbd>
      // }
      labelPlacement="outside"
      placeholder="Search..."
      startContent={
        <SearchIcon className="text-base text-default-400 pointer-events-none flex-shrink-0" />
      }
      type="search"
    />
  );

  const fullPath: string = usePathname();
  const router = useRouter();
  const { toast } = useContext(ToastContext);
  const logoutUser = async () => {
    const auth = getAuth(app);

    try {
      await signOut(auth);
      toast({
        message: "User Logged Out",
        type: "warning",
      });
      router.push("/");
    } catch (err) {
      console.log(JSON.stringify(err));
      toast({
        message: "An Error Occurred! Please try again later",
        type: "error",
      });
    }
  };

  return (
    <NextUINavbar maxWidth="xl" position="sticky">
      <NavbarContent className="basis-1/5 sm:basis-full" justify="start">
        <NavbarBrand as="li" className="gap-3 max-w-fit">
          <NextLink
            className="justify-start items-center gap-1 hidden md:flex"
            href={fullPath && fullPath.includes("home") ? "/home" : "/"}
          >
            {/* <ToothBrushIcon /> */}
            <div className="relative w-4 h-4 md:h-6 md:w-6">
              <Image src="/images/logo-image.png" fill alt="logo" />
            </div>
            <p className="font-bold text-lg">Amplify Dentistry</p>
          </NextLink>
          <NextLink
            className="justify-start items-center gap-1 flex md:hidden"
            href={fullPath && fullPath.includes("home") ? "/home" : "/"}
          >
            {/* <ToothBrushIcon /> */}
            <p className="font-bold text-lg">Home</p>
          </NextLink>
        </NavbarBrand>
        {/* <ul className="hidden lg:flex gap-4 justify-start ml-2">
          {siteConfig.navItems.map((item) => (
            <NavbarItem key={item.href}>
              <NextLink
                className={clsx(
                  linkStyles({ color: "foreground" }),
                  "data-[active=true]:text-primary data-[active=true]:font-medium",
                )}
                color="foreground"
                href={fullPath.includes("home") ? "/home" : item.href}
              >
                {item.label}
              </NextLink>
            </NavbarItem>
          ))}
        </ul> */}
      </NavbarContent>

      <NavbarContent
        className="hidden sm:flex basis-1/5 sm:basis-full"
        justify="end"
      >
        <NavbarItem className="hidden sm:flex gap-2">
          <Link
            isExternal
            aria-label="Github"
            href={
              fullPath && fullPath.includes("home")
                ? "https://github.com/SailendraDarbha94/amplify-dentistry"
                : siteConfig.links.github
            }
          >
            <GithubIcon className="text-default-500" />
          </Link>
          <Link
            isExternal={fullPath && fullPath.includes("home") ? false : true}
            aria-label="Portfolio"
            href={
              fullPath && fullPath.includes("home")
                ? "/home/profile"
                : siteConfig.links.portfolio
            }
          >
            <PortfolioIcon />
          </Link>
          <ThemeSwitch />
        </NavbarItem>
        {/* <NavbarItem className="hidden lg:flex">{searchInput}</NavbarItem> */}
        {fullPath && fullPath.includes("home") ? (
          <NavbarItem className="">
            <Button
              variant="flat"
              onPress={logoutUser}
              className="text-sm font-normal text-default-600 bg-default-100"
              startContent={<LogoutIcon className="text-danger" />}
            >
              Logout
            </Button>
          </NavbarItem>
        ) : null}
      </NavbarContent>

      <NavbarContent className="sm:hidden basis-1 pl-4" justify="end">
        <Link isExternal aria-label="Github" href={siteConfig.links.github}>
          <GithubIcon className="text-default-500" />
        </Link>
        <Link
          isExternal={fullPath && fullPath.includes("home") ? false : true}
          aria-label="Portfolio"
          href={
            fullPath && fullPath.includes("home")
              ? "/home/profile"
              : siteConfig.links.portfolio
          }
        >
          <PortfolioIcon />
        </Link>
        <ThemeSwitch />
        {/* <NavbarMenuToggle /> */}
        {fullPath && fullPath.includes("home") ? (
          <NavbarItem className="">
            <Button
              variant="flat"
              onPress={logoutUser}
              className="text-sm font-normal text-default-600 bg-default-100"
              startContent={<LogoutIcon className="text-danger" />}
            >
              Logout
            </Button>
          </NavbarItem>
        ) : null}
      </NavbarContent>

      {/* <NavbarMenu>
        {searchInput}
        <div className="mx-4 mt-2 justify-around min-h-48 max-h-full flex flex-col gap-4 items-center">
          {siteConfig.navMenuItems.map((item, index) => (
            <NavbarMenuItem key={`${item}-${index}`}>
              <Link
                className=""
                color={
                  index === 2
                    ? "primary"
                    : index === siteConfig.navMenuItems.length - 1
                      ? "primary"
                      : "foreground"
                }
                href={item.href}
                size="lg"
              >
                <h1 className="text-center">{item.label}</h1>
              </Link>
            </NavbarMenuItem>
          ))}
          {fullPath && fullPath.includes("home") ? (
            <NavbarMenuItem className="hidden md:flex">
              <Button
                variant="flat"
                onPress={logoutUser}
                className="text-sm font-normal text-default-600 bg-default-100"
                startContent={<LogoutIcon className="text-danger" />}
              >
                Logout
              </Button>
            </NavbarMenuItem>
          ) : null}
        </div>
      </NavbarMenu> */}
    </NextUINavbar>
  );
};
