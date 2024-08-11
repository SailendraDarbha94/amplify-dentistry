export const yearWiseSubjects = (year: string) => {
  switch (year) {
    case "first":
      return [
        "Dental Anatomy & Histology",
        "Physiology",
        "BioChemistry",
        "Human Anatomy",
      ];
    case "second":
      return [
        "Dental Materials",
        "Pharmacy",
        "Pre-Clinical Prosthodontics",
        "Pre-Clinical Endodontics",
        "Microbiology & Pathology",
      ];
    case "third":
      return ["General Surgery", "General Medicine", "Oral Pathology"];
    case "fourth":
      return [
        "Endodontics",
        "Prosthodontics",
        "Pedodontics",
        "Orthodontics",
        "Oral Medicine & Radiology",
        "Public Health Dentistry",
        "Periodontics",
        "Oral Surgery",
      ];
    default:
      return ["subjects", "not", "found"];
  }
};
