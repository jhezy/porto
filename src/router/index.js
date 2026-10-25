import { createRouter, createWebHistory } from "vue-router";
import { supabase, isSupabaseConfigured } from "../lib/supabase";

import HomeView from "../views/HomeView.vue";
import ProjectDetailView from "../views/ProjectDetailView.vue";
import LoginView from "../views/LoginView.vue";
import AdminLayout from "../views/admin/AdminLayout.vue";
import AdminDashboardView from "../views/admin/AdminDashboardView.vue";
import AdminProjectsView from "../views/admin/AdminProjectsView.vue";
import NotFoundView from "../views/NotFoundView.vue";
import ProfileView from "../views/admin/ProfileView.vue";
import ExperienceView from "../views/admin/ExperiencesView.vue";
import CertificatesView from "../views/admin/AdminCertificatesView.vue";

const routes = [
  { path: "/", name: "home", component: HomeView },
  {
    path: "/projects/:slug",
    name: "project-detail",
    component: ProjectDetailView,
  },
  {
    path: "/admin/login",
    name: "admin-login",
    component: LoginView,
    meta: { guestOnly: true },
  },
  {
    path: "/admin",
    component: AdminLayout,
    meta: { requiresAuth: true },
    children: [
      { path: "", name: "admin-dashboard", component: AdminDashboardView },
      {
        path: "projects",
        name: "admin-projects",
        component: AdminProjectsView,
      },
      {
        path: "profile",
        name: "admin-profile",
        component: ProfileView,
      },
      {
        path: "experience",
        name: "admin-experience",
        component: ExperienceView,
      },
      {
        path: "certificates",
        name: "admin-certificates",
        component: CertificatesView,
      },
    ],
  },
  { path: "/:pathMatch(.*)*", name: "not-found", component: NotFoundView },
];

const router = createRouter({
  history: createWebHistory(),
  routes,
  scrollBehavior() {
    return { top: 0, behavior: "smooth" };
  },
});

router.beforeEach(async (to) => {
  if (to.meta.requiresAuth) {
    if (!isSupabaseConfigured || !supabase)
      return { name: "admin-login", query: { setup: "supabase" } };
    const {
      data: { session },
    } = await supabase.auth.getSession();
    if (!session)
      return { name: "admin-login", query: { redirect: to.fullPath } };
  }

  if (to.meta.guestOnly && isSupabaseConfigured && supabase) {
    const {
      data: { session },
    } = await supabase.auth.getSession();
    if (session) return { name: "admin-dashboard" };
  }
});

export default router;
