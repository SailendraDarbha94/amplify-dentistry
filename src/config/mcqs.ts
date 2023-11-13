export interface QuestionItem {
    id: number;
    question: string;
    answer: string;
    options: string[];
}

export const anatomyQuestions: QuestionItem[] = [
    {
      id: 1,
      question:
        "Which bone in the skull is known as the 'keystone' due to its central position?",
      answer: "Sphenoid bone",
      options: [
        "Frontal bone",
        "Parietal bone",
        "Temporal bone",
        "Sphenoid bone",
      ],
    },
    {
      id: 2,
      question:
        "The carotid arteries, major blood vessels supplying the head and neck, are branches of which larger vessel?",
      answer: "Brachiocephalic artery",
      options: [
        "Aorta",
        "Subclavian artery",
        "Brachiocephalic artery",
        "Common iliac artery",
      ],
    },
    {
      id: 3,
      question:
        "The cranial nerve responsible for controlling eye movement and pupil constriction is:",
      answer: "Oculomotor nerve (III)",
      options: [
        "Olfactory nerve (I)",
        "Trochlear nerve (IV)",
        "Abducens nerve (VI)",
        "Oculomotor nerve (III)",
      ],
    },
    {
      id: 4,
      question:
        "Which muscle is responsible for elevating the mandible during chewing or biting?",
      answer: "Masseter",
      options: ["Masseter", "Temporalis", "Sternocleidomastoid", "Digastric"],
    },
    {
      id: 5,
      question: "The hyoid bone is unique in the human body because:",
      answer: "It is the only bone not connected to another bone.",
      options: [
        "It articulates with the skull.",
        "It is the only bone not connected to another bone.",
        "It is part of the vertebral column.",
        "It houses the auditory ossicles.",
      ],
    },
    {
      id: 6,
      question:
        "The parotid gland, a major salivary gland, is located adjacent to which structure?",
      answer: "External auditory canal",
      options: [
        "Submandibular gland",
        "Maxilla",
        "Mastoid process",
        "External auditory canal",
      ],
    },
    {
      id: 7,
      question: "Which of the following structures is NOT part of the pharynx?",
      answer: "Thyroid cartilage",
      options: [
        "Nasopharynx",
        "Oropharynx",
        "Laryngopharynx",
        "Thyroid cartilage",
      ],
    },
    {
      id: 8,
      question:
        "The vertebral artery, a key blood vessel in the neck, primarily supplies blood to:",
      answer: "The brain",
      options: [
        "The brain",
        "The spinal cord",
        "The thyroid gland",
        "The trachea",
      ],
    },
    {
      id: 9,
      question: "The optic nerve carries signals related to:",
      answer: "Vision",
      options: ["Taste", "Hearing", "Vision", "Smell"],
    },
    {
      id: 10,
      question: "The foramen magnum is an opening in which bone of the skull?",
      answer: "Occipital bone",
      options: [
        "Frontal bone",
        "Occipital bone",
        "Parietal bone",
        "Temporal bone",
      ],
    },
  ];
  
export const orthodonticQuestions = [
    {
      id: 1,
      question: "Which orthodontic appliance is commonly used to correct misalignment and crowding?",
      answer: "Dental Braces",
      options: ["Dental Braces", "Retainers", "Aligners", "Headgear"],
    },
    {
      id: 2,
      question: "What is the purpose of orthodontic retainers?",
      answer: "Maintain tooth alignment",
      options: ["Prevent cavities", "Improve chewing", "Maintain tooth alignment", "Reduce gum swelling"],
    },
    {
      id: 3,
      question: "Which orthodontic issue is often treated with a palatal expander?",
      answer: "Narrow dental arch",
      options: ["Overbite", "Narrow dental arch", "Gapped teeth", "Underbite"],
    },
    {
      id: 4,
      question: "What is the common material used for traditional braces?",
      answer: "Metal brackets and wires",
      options: ["Plastic", "Metal brackets and wires", "Ceramic", "Wood"],
    },
    {
      id: 5,
      question: "What is the primary function of orthodontic elastics (rubber bands)?",
      answer: "Adjust jaw alignment",
      options: ["Whiten teeth", "Reduce tooth sensitivity", "Adjust jaw alignment", "Prevent tooth decay"],
    },
    {
      id: 6,
      question: "Which orthodontic appliance is worn to address thumb-sucking habits?",
      answer: "Palatal crib",
      options: ["Lip bumper", "Tongue crib", "Palatal crib", "Nance appliance"],
    },
    {
      id: 7,
      question: "In orthodontics, what is malocclusion?",
      answer: "Misalignment of teeth",
      options: ["Gum disease", "Tooth decay", "Misalignment of teeth", "Jaw fracture"],
    },
    {
      id: 8,
      question: "What is the purpose of a Herbst appliance in orthodontics?",
      answer: "Correct jaw discrepancies",
      options: ["Straighten crooked teeth", "Whiten tooth enamel", "Correct jaw discrepancies", "Prevent tooth loss"],
    },
    {
      id: 9,
      question: "Which orthodontic treatment is designed for discreet teeth straightening?",
      answer: "Invisalign",
      options: ["Metal braces", "Invisalign", "Lingual braces", "Power chains"],
    },
    {
      id: 10,
      question: "What is the main goal of orthodontic treatment?",
      answer: "Achieve a functional bite and pleasing aesthetics",
      options: ["Eliminate bad breath", "Reduce gum bleeding", "Achieve a functional bite and pleasing aesthetics", "Prevent enamel erosion"],
    },
  ];

export const publicHealthQuestions = [
    {
      id: 1,
      question: "What is the primary goal of community water fluoridation?",
      answer: "Prevent tooth decay",
      options: ["Improve taste", "Enhance color", "Prevent tooth decay", "Reduce hardness"],
    },
    {
      id: 2,
      question: "Which fluoridation method is commonly used in water supplies?",
      answer: "Fluorosilicic acid",
      options: ["Fluorosilicic acid", "Sodium chloride", "Calcium hydroxide", "Potassium fluoride"],
    },
    {
      id: 3,
      question: "Which dental condition is often associated with tobacco use?",
      answer: "Periodontal disease",
      options: ["Cavities", "Gingivitis", "Periodontal disease", "Dry mouth"],
    },
    {
      id: 4,
      question: "What is the main purpose of dental sealants?",
      answer: "Prevent cavities on molars",
      options: ["Whiten teeth", "Straighten teeth", "Prevent cavities on molars", "Reduce gum bleeding"],
    },
    {
      id: 5,
      question: "Which organization is a major advocate for oral health promotion?",
      answer: "World Health Organization",
      options: ["Red Cross", "World Dental Association", "World Health Organization", "United Nations"],
    },
    {
      id: 6,
      question: "What is the most common chronic disease in children?",
      answer: "Dental caries",
      options: ["Asthma", "Diabetes", "Dental caries", "Obesity"],
    },
    {
      id: 7,
      question: "Which age group is often targeted for school-based dental sealant programs?",
      answer: "Children in elementary schools",
      options: ["High school students", "College students", "Preschool children", "Children in elementary schools"],
    },
    {
      id: 8,
      question: "What is the recommended fluoride concentration in toothpaste for adults?",
      answer: "1000-1500 ppm",
      options: ["500 ppm", "1000-1500 ppm", "2000 ppm", "3000 ppm"],
    },
    {
      id: 9,
      question: "Which dental professional is specialized in public health dentistry?",
      answer: "Dental public health specialist",
      options: ["Orthodontist", "Pediatric dentist", "Prosthodontist", "Dental public health specialist"],
    },
    {
      id: 10,
      question: "What is the primary focus of community-based dental education programs?",
      answer: "Preventive care and community service",
      options: ["Advanced dental procedures", "Cosmetic dentistry", "Preventive care and community service", "Emergency dental care"],
    },
  ];
  
  
  