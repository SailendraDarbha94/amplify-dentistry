"use client";
import {
  Navbar as NextUINavbar,
  NavbarContent,
  NavbarMenu,
  NavbarMenuToggle,
  NavbarItem,
  NavbarMenuItem,
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

import { siteConfig } from "@/config/site";
import { ThemeSwitch } from "@/components/theme-switch";
import {
  GithubIcon,
  SearchIcon,
  PortfolioIcon,
  LogoutIcon,
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

  const fullPath = usePathname();
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
        {/* <NavbarBrand as="li" className="gap-3 max-w-fit">
          <NextLink className="flex justify-start items-center gap-1" href="/">
            <ToothBrushIcon />
            <p className="font-bold text-inherit">AmpDent</p>
          </NextLink>
        </NavbarBrand> */}
        <ul className="hidden lg:flex gap-4 justify-start ml-2">
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
        </ul>
      </NavbarContent>

      <NavbarContent
        className="hidden sm:flex basis-1/5 sm:basis-full"
        justify="end"
      >
        <NavbarItem className="hidden sm:flex gap-2">
          {/* <Link isExternal aria-label="Twitter" href={siteConfig.links.twitter}>
            <TwitterIcon className="text-default-500" />
          </Link> */}
          <Link isExternal aria-label="Github" href={siteConfig.links.github}>
            <GithubIcon className="text-default-500" />
          </Link>
          <Link
            isExternal={fullPath.includes("home") ? false : true}
            aria-label="Portfolio"
            href={
              fullPath.includes("home")
                ? "/home/profile"
                : siteConfig.links.portfolio
            }
          >
            <PortfolioIcon />
          </Link>
          <ThemeSwitch />
        </NavbarItem>
        {/* <NavbarItem className="hidden lg:flex">{searchInput}</NavbarItem> */}
        {fullPath.includes("home") ? (
          <NavbarItem className="hidden md:flex">
            <Button
              //isExternal
              //as={Link}
              variant="flat"
              onPress={logoutUser}
              className="text-sm font-normal text-default-600 bg-default-100"
              //href={siteConfig.links.sponsor}
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
        <ThemeSwitch />
        <NavbarMenuToggle />
      </NavbarContent>

      <NavbarMenu>
        {searchInput}
        <div className="mx-4 mt-2 flex flex-col gap-2">
          {siteConfig.navMenuItems.map((item, index) => (
            <NavbarMenuItem key={`${item}-${index}`}>
              <Link
                color={
                  index === 2
                    ? "primary"
                    : index === siteConfig.navMenuItems.length - 1
                      ? "danger"
                      : "foreground"
                }
                href="#"
                size="lg"
              >
                {item.label}
              </Link>
            </NavbarMenuItem>
          ))}
        </div>
      </NavbarMenu>
    </NextUINavbar>
  );
};
