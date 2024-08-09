"use client";
import { createUserWithEmailAndPassword, getAuth } from "firebase/auth";
import { useState } from "react";
import { Button } from "@nextui-org/button";

import { emptyUserFormData, User } from "./constants";

import app from "@/config/firebase";

const Form = ({ saveUserData }: any) => {
  const auth = getAuth(app);

  const [loading, setLoading] = useState<boolean>(false);
  const [userDetails, setUserDetails] = useState<User>(emptyUserFormData);

  const handleChange = (e: any) => {
    const { name, value }: any = e.target;

    setUserDetails((prevState) => ({ ...prevState, [name]: value }));
  };

  const handleSubmit = async (e: any) => {
    setLoading(true);
    e.preventDefault();
    if (userDetails.password.length < 8) {
      setLoading(false);
      alert("Password must be at least 8 characters long");

      return;
    }

    if (userDetails.password !== userDetails.confirmPassword) {
      setLoading(false);
      alert("Password and Confirm Password are not matching");

      return;
    }

    try {
      const { user } = await createUserWithEmailAndPassword(
        auth,
        userDetails.email,
        userDetails.password,
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
        <div className="w-full h-full flex justify-center items-center font-bold">
          Loading...
        </div>
      ) : (
        <form onSubmit={handleSubmit}>
          {/* <h1 className="text-xl font-bold leading-tight tracking-tight text-gray-900 md:text-2xl dark:text-white">
            Sign up for an Account
          </h1> */}
          <br />
          <div>
            <label
              className="block mb-2 text-sm font-medium text-gray-900 dark:text-white"
              htmlFor="name"
            >
              Full Name
            </label>
            <input
              className="bg-gray-50 border focus:outline-none border-gray-300 text-gray-900 sm:text-sm rounded-lg block w-full p-2.5 dark:bg-gray-700 dark:border-gray-600 dark:placeholder-gray-400 dark:text-white"
              id="name"
              name="name"
              placeholder=""
              required={true}
              type="text"
              value={userDetails.name}
              onChange={handleChange}
            />
          </div>
          <br />
          <div>
            <label
              className="block mb-2 text-sm font-medium text-gray-900 dark:text-white"
              htmlFor="email"
            >
              E-Mail Address
            </label>
            <input
              className="bg-gray-50 border focus:outline-none border-gray-300 text-gray-900 sm:text-sm rounded-lg block w-full p-2.5 dark:bg-gray-700 dark:border-gray-600 dark:placeholder-gray-400 dark:text-white"
              id="email"
              name="email"
              placeholder="someone@example.com"
              required={true}
              type="email"
              value={userDetails.email}
              onChange={handleChange}
            />
          </div>
          <br />
          <div>
            <label
              className="block mb-2 text-sm font-medium text-gray-900 dark:text-white"
              htmlFor="password"
            >
              Password
            </label>
            <input
              className="bg-gray-50 border focus:outline-none border-gray-300 text-gray-900 sm:text-sm rounded-lg block w-full p-2.5 dark:bg-gray-700 dark:border-gray-600 dark:placeholder-gray-400 dark:text-white"
              id="password"
              name="password"
              placeholder=""
              required={true}
              type="password"
              value={userDetails.password}
              onChange={handleChange}
            />
          </div>
          <br />
          <div>
            <label
              className="block mb-2 text-sm font-medium text-gray-900 dark:text-white"
              htmlFor="confirmPassword"
            >
              Confirm Password
            </label>
            <input
              className="bg-gray-50 border focus:outline-none border-gray-300 text-gray-900 sm:text-sm rounded-lg block w-full p-2.5 dark:bg-gray-700 dark:border-gray-600 dark:placeholder-gray-400 dark:text-white"
              id="confirmPassword"
              name="confirmPassword"
              placeholder=""
              required={true}
              type="password"
              value={userDetails.confirmPassword}
              onChange={handleChange}
            />
          </div>
          <br />
          {/* <button
            className="block bg-sky-300 dark:bg-sky-600 p-2 rounded-md mx-auto"
            type="submit"
          >
            Submit
          </button> */}
          <Button
            className="mx-auto block text-lg"
            color="primary"
            type="submit"
            variant="ghost"
          >
            Submit
          </Button>
        </form>
      )}
    </>
  );
};

export default Form;
