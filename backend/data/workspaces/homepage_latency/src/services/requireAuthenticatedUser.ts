export async function requireAuthenticatedUser(userId: string): Promise<void> {
  const response = await fetch(`/internal/auth/session?userId=${userId}`);
  if (!response.ok) {
    throw new Error("Unauthenticated user");
  }
}
