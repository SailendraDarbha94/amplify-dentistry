
import { Metadata } from "next";

// export function cn(...inputs: ClassValue[]) {
//   return twMerge(clsx(inputs));
// }

export function absoluteUrl(path: string) {
  if (typeof window !== "undefined") return path;
  if (process.env.VERCEL_URL) return `https://${process.env.VERCEL_URL}${path}`;
  return `http://localhost:${process.env.PORT ?? 3000}${path}`;
}

export function constructMetadata({
  title = "AmpDent - a platform for dental community",
  description = "Ampdent is a unique and innovative platform to help Dental students study in a more engaging & interactive way.",
  image = "/thumbnail.png",
  icons = "/favicon.ico",
  noIndex = false,
}: {
  title?: string;
  description?: string;
  image?: string;
  icons?: string;
  noIndex?: boolean;
} = {}): Metadata {
  return {
    title,
    description,
    openGraph: {
      title,
      description,
      images: [
        {
          url: image,
        },
      ],
    },
    // twitter: {
    //   card: "summary_large_image",
    //   title,
    //   description,
    //   images: [image],
    //   creator: "@joshtriedcoding",
    // },
    // icons,
    //metadataBase: new URL("https://quill-jet.vercel.app"),
    themeColor: "#FFF",
    ...(noIndex && {
      robots: {
        index: false,
        follow: false,
      },
    }),
  };
}

export function promptsGenerator(sub: string) {
  const prompt = `take a range of 1 -100 in terms of difficulty, then generate 10 multiple choice questions in the subject of ${sub} as it relates to Dentists around range 70, then
convert these in this JSON format  questions : {
id: 1,
question: "multiple choice question",
answer: "text content of answer",
options: [ "option 1", "option 2", "option 3", "option 4" ]
}
make sure that the options should not have more than 2-3 words in them but also make sure the correct answer will pass '===' operator with the correct option`;
  return prompt;
}