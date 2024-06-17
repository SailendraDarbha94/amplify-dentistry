"use client";

import app from "@/lib/firebase";
import { createUserWithEmailAndPassword, getAuth } from "firebase/auth";
import { useState } from "react";

interface User {
  name: string;
  email: string;
  password: string;
  confirmPassword: string;
}

const Form = ({ saveUserData }: any) => {
  const auth = getAuth(app);

  const emptyUserFormData: User = {
    name: "",
    email: "",
    password: "",
    confirmPassword: "",
  };

  const [loading, setLoading] = useState<boolean>(false);
  const [userDetails, setUserDetails] = useState<User>(emptyUserFormData);

  const handleChange = (e: any) => {
    const { name, value }: any = e.target;
    setUserDetails((prevState) => ({ ...prevState, [name]: value }));
  };

  const handleSubmit = async (e: any) => {
    setLoading(true);

    if(userDetails.password.length < 8){
      setLoading(false)
      alert("Password must be at least 8 characters long");
      return
    }

    if (userDetails.password !== userDetails.confirmPassword) {
      setLoading(false)
      alert("Password and Confirmpassword are not matching");
      return;
    }

    e.preventDefault();

    try {
      const { user } = await createUserWithEmailAndPassword(
        auth,
        userDetails.email,
        userDetails.password
      );
      saveUserData(user.uid, userDetails.name, userDetails.email);
      setUserDetails(emptyUserFormData);
      setLoading(false);

    } catch (err) {
      setLoading(false);
      JSON.stringify(err);
    }
  };

  return (
    <>
      {loading ? (
        <div className="w-full h-full flex justify-center items-center font-pExtraBold">
          Loading...
        </div>
      ) : (
        <form onSubmit={handleSubmit}>
          <h1 className="text-xl font-bold leading-tight tracking-tight text-gray-900 md:text-2xl dark:text-white">
            Sign up for an Account
          </h1>
          <br />
          <div>
            <label
              htmlFor="name"
              className="block mb-2 text-sm font-medium text-gray-900 dark:text-white"
            >
              Full Name
            </label>
            <input
              type="text"
              name="name"
              id="name"
              value={userDetails.name}
              onChange={handleChange}
              className="bg-gray-50 border focus:outline-none border-gray-300 text-gray-900 sm:text-sm rounded-lg block w-full p-2.5 dark:bg-gray-700 dark:border-gray-600 dark:placeholder-gray-400 dark:text-white"
              placeholder=""
              required={true}
            />
          </div>
          <br />
          <div>
            <label
              htmlFor="email"
              className="block mb-2 text-sm font-medium text-gray-900 dark:text-white"
            >
              Electronic Mail Address
            </label>
            <input
              type="email"
              name="email"
              id="email"
              value={userDetails.email}
              onChange={handleChange}
              className="bg-gray-50 border focus:outline-none border-gray-300 text-gray-900 sm:text-sm rounded-lg block w-full p-2.5 dark:bg-gray-700 dark:border-gray-600 dark:placeholder-gray-400 dark:text-white"
              placeholder="someone@example.com"
              required={true}
            />
          </div>
          <br />
          <div>
            <label
              htmlFor="password"
              className="block mb-2 text-sm font-medium text-gray-900 dark:text-white"
            >
              Password
            </label>
            <input
              type="password"
              name="password"
              id="password"
              value={userDetails.password}
              onChange={handleChange}
              className="bg-gray-50 border focus:outline-none border-gray-300 text-gray-900 sm:text-sm rounded-lg block w-full p-2.5 dark:bg-gray-700 dark:border-gray-600 dark:placeholder-gray-400 dark:text-white"
              placeholder=""
              required={true}
            />
          </div>
          <br />
          <div>
            <label
              htmlFor="confirmPassword"
              className="block mb-2 text-sm font-medium text-gray-900 dark:text-white"
            >
              Confirm Password
            </label>
            <input
              type="password"
              name="confirmPassword"
              id="confirmPassword"
              value={userDetails.confirmPassword}
              onChange={handleChange}
              className="bg-gray-50 border focus:outline-none border-gray-300 text-gray-900 sm:text-sm rounded-lg block w-full p-2.5 dark:bg-gray-700 dark:border-gray-600 dark:placeholder-gray-400 dark:text-white"
              placeholder=""
              required={true}
            />
          </div>
          <br />
          <button
            type="submit"
            className="block bg-sky-300 dark:bg-sky-600 p-2 rounded-md mx-auto"
          >
            Submit
          </button>
        </form>
      )}
    </>
  );
};

export default Form;
