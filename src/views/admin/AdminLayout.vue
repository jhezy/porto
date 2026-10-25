<script setup>
import { ref, onMounted, onUnmounted } from "vue";
import { RouterLink, RouterView, useRouter } from "vue-router";
import { supabase } from "../../lib/supabase";

const router = useRouter();
const email = ref("");
let authListener;

onMounted(async () => {
  if (!supabase) return;
  const { data } = await supabase.auth.getUser();
  email.value = data.user?.email || "";
  const result = supabase.auth.onAuthStateChange((_event, session) => {
    if (!session) router.replace("/admin/login");
    email.value = session?.user?.email || "";
  });
  authListener = result.data.subscription;
});
onUnmounted(() => authListener?.unsubscribe());

async function signOut() {
  if (supabase) await supabase.auth.signOut();
  await router.replace("/admin/login");
}
</script>

<template>
  <div class="admin-shell">
    <aside class="admin-sidebar">
      <RouterLink
        to="/"
        class="d-flex align-items-center gap-2 fw-bold px-2 mb-4"
        ><span class="brand-mark">P.</span
        ><span>PORTFOLIO<span class="text-accent">/</span></span></RouterLink
      >
      <div
        class="text-uppercase text-muted-custom small fw-bold px-3 mb-2"
        style="letter-spacing: 0.12em"
      >
        Workspace
      </div>
      <nav class="admin-nav d-grid gap-1">
        <RouterLink
          to="/admin"
          class="admin-nav-link"
          ><i class="bi bi-grid-1x2"></i> Overview</RouterLink
        >
        <RouterLink
          to="/admin/projects"
          class="admin-nav-link"
          ><i class="bi bi-window-stack"></i> Proyek</RouterLink
        >
        <RouterLink
          to="/admin/profile"
          class="admin-nav-link"
          ><i class="bi bi-window-stack"></i> Profil</RouterLink
        >
        <router-link
          to="/admin/experience"
          class="admin-nav-link"
          ><i class="bi bi-briefcase"></i> Pengalaman</router-link
        >
        <RouterLink
          to="/admin/certificates"
          class="admin-nav-link"
          ><i class="bi bi-award"></i> Sertifikat</RouterLink
        >
      </nav>

      <div
        class="d-none d-md-block mt-5 px-2 text-muted-custom small text-break"
      >
        {{ email }}
      </div>
      <button
        @click="signOut"
        class="btn btn-outline-soft w-100 mt-3"
      >
        <i class="bi bi-box-arrow-right me-2"></i>Keluar
      </button>
    </aside>
    <main class="admin-main">
      <RouterView />
    </main>
  </div>
</template>
