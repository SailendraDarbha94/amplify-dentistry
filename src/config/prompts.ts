export const PROMPT = `take a range of 1 -100 in terms of difficulty, then generate 2 multiple choice questions in the subject or Physiology as it relates to Dentists around range 70, then
convert these in this JSON format  questions : {
id: 1,
question: "multiple choice question",
answer: "text content of answer",
options: [ "option 1", "option 2", "option 3", "option 4" ]
}
make sure that the options should not have more than 2-3 words in them but also make sure the correct answer will pass '===' operator with the correct option`