export const firstYearSubjects: string[] = [
  "Dental Anatomy & Histology",
  "Physiology",
  "BioChemistry",
  "Human Anatomy",
];

export const secondYearSubjects: string[] = [
  "Dental Materials",
  "Pharmacy",
  "Pre-Clinical Prosthodontics",
  "Pre-Clinical Endodontics",
  "Microbiology & Pathology",
];

export const thirdYearSubjects: string[] = [
  "General Surgery",
  "General Medicine",
  "Oral Pathology",
];

export const fourthYearSubjects: string[] = [
  "Endodontics",
  "Prosthodontics",
  "Pedodontics",
  "Orthodontics",
  "Oral Medicine & Radiology",
  "Public Health Dentistry",
  "Periodontics",
  "Oral Surgery",
];

export const yearWiseSubjects = (year: string) => {
  switch (year) {
    case "first":
      return firstYearSubjects;
    case "second":
      return secondYearSubjects;
    case "third":
      return thirdYearSubjects;
    case "fourth":
      return fourthYearSubjects;
    default:
      return ["subjects", "not", "found"];
  }
};
