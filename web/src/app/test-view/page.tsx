"use client";

import { useState } from "react";

const Page = () => {
    const [loading, setLoading] = useState<boolean>(false);
    const [content, setContent] = useState<string>("");
    const [prompt, setPrompt] = useState<string>("");

    const chat = async () => {
        setLoading(true)
        try {
          const res = await fetch("/api/chat", {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              _prompt: prompt,
            }),
          });
          const { data } = await res.json();
          if (data) {
            setPrompt("");
            setContent(data.choices[0].message.content)
            setLoading(false)
          }
        } catch (err) {
          console.error(err);
          setLoading(false)
        }
      };

  return (
    <div className="w-full min-h-screen">
      <h1>Page</h1>
      <button className="m-4 p-2 rounded-xl text-cyan-400 bg-blue-700 text-center" onClick={chat}>
        {loading ? (<p>loading...</p>):(<p>click me</p>)}
      </button>
      <label htmlFor="something">input</label>
      <input className="w-80 rounded-md bg-slate-50 border-2 border-blue-500 mx-2 h-10 focus-visible:outline-none" id="something" type="text" value={prompt} onChange={e => setPrompt(e.target.value)} />

      {content ? (<div>
        {content}
      </div>):null}
    </div>
  );
};

export default Page;
