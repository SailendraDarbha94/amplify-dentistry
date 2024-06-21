// const chat = async () => {
//     setLoading(true)
//     try {
//       const res = await fetch("/api/chat", {
//         method: "POST",
//         headers: {
//           "Content-Type": "application/json",
//         },
//         body: JSON.stringify({
//           _prompt: prompt,
//         }),
//       });
//       const { data } = await res.json();
//       if (data) {
//         setPrompt("");
//         setContent(data.choices[0].message.content)
//         setLoading(false)
//       }
//     } catch (err) {
//       console.error(err);
//       setLoading(false)
//     }
//   };