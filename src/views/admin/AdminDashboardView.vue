<script setup>
import { onMounted, ref } from "vue";
import { supabase } from "../../lib/supabase";
import { RouterLink } from "vue-router";

const loading = ref(true);
const loadError = ref("");

const totalProjects = ref(0);
const publishedProjects = ref(0);
const draftProjects = ref(0);
const totalCategories = ref(0);
const recentProjects = ref([]);

const stats = [
  {
    label: "Total proyek",
    icon: "bi-window-stack",
    value: totalProjects,
    description: "Semua proyek tersimpan",
  },
  {
    label: "Published",
    icon: "bi-check-circle",
    value: publishedProjects,
    description: "Proyek tampil untuk publik",
  },
  {
    label: "Draft",
    icon: "bi-file-earmark",
    value: draftProjects,
    description: "Belum dipublikasikan",
  },
  {
    label: "Kategori",
    icon: "bi-grid",
    value: totalCategories,
    description: "Kategori proyek tersedia",
  },
];

function formatDate(value) {
  if (!value) return "Belum tersedia";

  return new Intl.DateTimeFormat("id-ID", {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(new Date(value));
}

async function loadDashboard() {
  loading.value = true;
  loadError.value = "";

  try {
    const [
      allResult,
      publishedResult,
      draftResult,
      categoryResult,
      recentResult,
    ] = await Promise.all([
      supabase.from("projects").select("id", { count: "exact", head: true }),

      supabase
        .from("projects")
        .select("id", { count: "exact", head: true })
        .eq("status", "published"),

      supabase
        .from("projects")
        .select("id", { count: "exact", head: true })
        .eq("status", "draft"),

      supabase
        .from("project_categories")
        .select("id", { count: "exact", head: true }),

      supabase
        .from("projects")
        .select("id, title, slug, status, thumbnail_url, created_at")
        .order("created_at", { ascending: false })
        .limit(5),
    ]);

    const failed = [
      allResult,
      publishedResult,
      draftResult,
      categoryResult,
      recentResult,
    ].find((result) => result.error);

    if (failed) throw failed.error;

    totalProjects.value = allResult.count ?? 0;
    publishedProjects.value = publishedResult.count ?? 0;
    draftProjects.value = draftResult.count ?? 0;
    totalCategories.value = categoryResult.count ?? 0;
    recentProjects.value = recentResult.data ?? [];
  } catch (err) {
    console.error("Dashboard error:", err);
    loadError.value = err.message || "Statistik dashboard gagal dimuat.";
  } finally {
    loading.value = false;
  }
}

onMounted(loadDashboard);
</script>

<template>
  <div
    class="d-flex flex-wrap justify-content-between align-items-start gap-3 mb-4"
  >
    <div>
      <p class="eyebrow mb-2">WORKSPACE / OVERVIEW</p>
      <h1 class="h2 fw-bold mb-1">Dashboard</h1>
      <p class="text-muted-custom mb-0">
        Ringkasan dan aktivitas pengelolaan portofolio.
      </p>
    </div>

    <RouterLink
      to="/admin/projects"
      class="btn btn-accent"
    >
      <i class="bi bi-plus-lg me-2"></i>
      Tambah proyek
    </RouterLink>
  </div>

  <div
    v-if="loadError"
    class="alert alert-danger"
  >
    {{ loadError }}
    <button
      class="btn btn-sm btn-outline-danger ms-2"
      @click="loadDashboard"
    >
      Coba lagi
    </button>
  </div>

  <div class="row g-3 mb-4">
    <div
      v-for="stat in stats"
      :key="stat.label"
      class="col-12 col-sm-6 col-xl-3"
    >
      <div class="panel p-4 h-100">
        <div class="d-flex justify-content-between align-items-center mb-3">
          <span class="text-muted-custom small">{{ stat.label }}</span>
          <i :class="['bi', stat.icon, 'text-accent fs-5']"></i>
        </div>

        <div class="display-6 fw-bold">
          <span v-if="loading">—</span>
          <span v-else>{{ stat.value }}</span>
        </div>

        <p class="text-muted-custom small mb-0 mt-2">
          {{ stat.description }}
        </p>
      </div>
    </div>
  </div>

  <div class="panel p-3 p-md-4 mb-4">
    <div
      class="d-flex flex-wrap justify-content-between align-items-center gap-3 mb-3"
    >
      <div>
        <p class="eyebrow mb-1">CONTENT MANAGEMENT</p>
        <h2 class="h5 fw-bold mb-0">Proyek terbaru</h2>
      </div>

      <RouterLink
        to="/admin/projects"
        class="btn btn-outline-soft btn-sm"
      >
        Lihat semua
        <i class="bi bi-arrow-right ms-1"></i>
      </RouterLink>
    </div>

    <div
      v-if="loading"
      class="text-muted-custom py-4"
    >
      Memuat proyek terbaru...
    </div>

    <div
      v-else-if="!loadError && recentProjects.length === 0"
      class="text-center py-5"
    >
      <i class="bi bi-folder2-open fs-1 text-accent"></i>
      <h3 class="h6 fw-semibold mt-3">Belum ada proyek</h3>
      <p class="text-muted-custom small">
        Tambahkan proyek pertamamu untuk mulai membangun portofolio.
      </p>
      <RouterLink
        to="/admin/projects"
        class="btn btn-accent btn-sm"
      >
        Tambah proyek
      </RouterLink>
    </div>

    <div
      v-else-if="!loadError"
      class="table-responsive"
    >
      <table class="table table-dark-custom align-middle mb-0">
        <thead>
          <tr>
            <th>Proyek</th>
            <th>Status</th>
            <th>Dibuat</th>
            <th class="text-end">Aksi</th>
          </tr>
        </thead>

        <tbody>
          <tr
            v-for="project in recentProjects"
            :key="project.id"
          >
            <td>
              <div class="d-flex align-items-center gap-3">
                <img
                  v-if="project.thumbnail_url"
                  :src="project.thumbnail_url"
                  :alt="project.title"
                  loading="lazy"
                  class="rounded-3"
                  style="width: 52px; height: 42px; object-fit: cover"
                />

                <div
                  v-else
                  class="rounded-3 d-flex align-items-center justify-content-center"
                  style="
                    width: 52px;
                    height: 42px;
                    background: var(--surface-2, #252a32);
                  "
                >
                  <i class="bi bi-image text-secondary"></i>
                </div>

                <div>
                  <div class="fw-semibold">{{ project.title }}</div>
                  <div class="text-muted-custom small">/{{ project.slug }}</div>
                </div>
              </div>
            </td>

            <td>
              <span
                :class="[
                  'badge rounded-pill',
                  project.status === 'published'
                    ? 'text-bg-success'
                    : 'text-bg-secondary',
                ]"
              >
                {{ project.status }}
              </span>
            </td>

            <td class="small text-muted-custom">
              {{ formatDate(project.created_at) }}
            </td>

            <td class="text-end">
              <RouterLink
                to="/admin/projects"
                class="btn btn-sm btn-outline-soft"
              >
                Kelola
              </RouterLink>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>

  <div class="panel p-4 p-md-5">
    <p class="eyebrow mb-2">NEXT STEP</p>
    <h2 class="h4 fw-bold">Bangun jejak digitalmu.</h2>
    <p class="text-muted-custom mb-4">
      Tampilkan karya terbaik, jelaskan teknologi yang digunakan, dan tambahkan
      tautan demo atau repositori agar pengunjung dapat mengenal kemampuanmu.
    </p>

    <RouterLink
      to="/admin/projects"
      class="btn btn-outline-soft"
    >
      Buka pengelolaan proyek
      <i class="bi bi-arrow-right ms-2"></i>
    </RouterLink>
  </div>
</template>
