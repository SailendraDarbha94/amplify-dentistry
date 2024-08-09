
export interface User {
    name: string;
    email: string;
    password: string;
    confirmPassword: string;
}


export const emptyUserFormData: User = {
    name: "",
    email: "",
    password: "",
    confirmPassword: "",
};