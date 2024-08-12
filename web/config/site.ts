export type SiteConfig = typeof siteConfig;

export const siteConfig = {
  name: "Amplify Dentistry",
  description:
    "Ampdent is an AI Platform for Dental Students powered by Gemini and built upon Firebase for speed, reliability and scalability",
  navItems: [
    {
      label: "Home",
      href: "/",
    },
    {
      label: "About",
      href: "/about",
    },
    // {
    //   label: "Pricing",
    //   href: "/pricing",
    // },
    {
      label: "Blog",
      href: "/blog",
    },
    {
      label: "Docs",
      href: "/docs",
    },
  ],
  navMenuItems: [
    {
      label: "Home",
      href: "/home",
    },
    // {
    //   label: "Profile",
    //   href: "/home/profile",
    // },
    // {
    //   label: "Projects",
    //   href: "/projects",
    // },
    // {
    //   label: "Team",
    //   href: "/team",
    // },
    // {
    //   label: "Calendar",
    //   href: "/calendar",
    // },
    // {
    //   label: "Settings",
    //   href: "/settings",
    // },
    // {
    //   label: "Help & Feedback",
    //   href: "/help-feedback",
    // },
    // {
    //   label: "Logout",
    //   href: "/logout",
    // },
  ],
  links: {
    github: "https://github.com/SailendraDarbha94",
    twitter: "https://twitter.com/getnextui",
    docs: "https://nextui.org",
    discord: "https://discord.gg/9b6yyZKmH4",
    sponsor: "https://patreon.com/jrgarciadev",
    portfolio: "https://www.sailendradarbha.fyi/",
  },
  internalLinks: {
    signUp: "/sign-up",
  },
};
