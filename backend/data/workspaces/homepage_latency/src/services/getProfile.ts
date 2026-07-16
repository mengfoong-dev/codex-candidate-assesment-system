export async function getProfile(userId: string) {
  const response = await fetch(`/internal/profile?userId=${userId}`);
  return response.json();
}
