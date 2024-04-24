"use client"
import Link from "next/link";
import MaxWidthWrapper from "./MaxWidthWrapper";
import { buttonVariants } from "./ui/button";
import { ArrowRight } from "lucide-react";
import UserAccountNav from "./UserAccountNav";
import MobileNav from "./MobileNav";
import { useAuthContext } from "@/context/AuthContext";
import { Button } from "@nextui-org/react";
import { getAuth } from "firebase/auth";
import firebase_app from "@/firebase/config";
import { toast } from "./ui/use-toast";
import { useRouter } from "next/navigation";

const Navbar = () => {
  const { user }: any = useAuthContext();
  const auth = getAuth(firebase_app);
  const router = useRouter()
  const logouter = async () => {
    try {
      await auth.signOut();
      router.push("/");
    } catch (err) {
      if(err){
        console.error("error occured", err)
      }
    }
  };
  return (
    <nav className="sticky h-14 inset-x-0 top-0 z-30 w-full border-b border-gray-200 bg-white/75 backdrop-blur-lg transition-all">
      <MaxWidthWrapper>
        <div className="flex h-14 items-center justify-between border-b border-zinc-200">
          <Link href="/" className="flex z-40 font-bold">
            <span className="text-lg">AmplifyDentistry</span>
          </Link>
          {user ? (
            <div className="flex">
              <Link
                href="/auth/sign-up"
                className="flex z-40 text-blue-700 mx-2 font-semibold "
              >
                <span>Profile</span>
              </Link>
              <Button size="md" color="danger" className="text-red-500 font-semibold" onClick={logouter}>
                LogOut
              </Button>
            </div>
          ) : (
            <div className="flex">
              <Link
                href="/auth/sign-up"
                className="flex z-40 mx-2 font-semibold "
              >
                <span>Sign-Up</span>
              </Link>
              <Link href="/auth/login" className="flex z-40 mx-2 font-semibold">
                <span>Login</span>
              </Link>
            </div>
          )}

          {/* <Link
            href='/'
            className='flex z-40 font-semibold'>
            <span>AmplifyDentistry</span>
          </Link>

            <MobileNav isAuth={!!user} />

            <div className='hidden items-center space-x-4 sm:flex'>
            {!user ? (
              <>
                <Link
                  href='/pricing'
                  className={buttonVariants({
                    variant: 'ghost',
                    size: 'sm',
                  })}>
                  Pricing
                </Link>
                <LoginLink
                  className={buttonVariants({
                    variant: 'ghost',
                    size: 'sm',
                  })}>
                  Sign in
                </LoginLink>
                <RegisterLink
                  className={buttonVariants({
                    size: 'sm',
                  })}>
                  Get started{' '}
                  <ArrowRight className='ml-1.5 h-5 w-5' />
                </RegisterLink>
              </>
            ) : (
              <>
                <Link
                  href='/dashboard'
                  className={buttonVariants({
                    variant: 'ghost',
                    size: 'sm',
                  })}>
                  Home
                </Link>

                <UserAccountNav
                  name={
                    !user.given_name || !user.family_name
                      ? 'Your Account'
                      : `${user.given_name} ${user.family_name}`
                  }
                  email={user.email ?? ''}
                  imageUrl={user.picture ?? ''}
                />
              </>
            )}
          </div> */}
        </div>
      </MaxWidthWrapper>
    </nav>
  );
};

export default Navbar;
