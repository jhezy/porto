<script setup>
import { onMounted, onBeforeUnmount, ref } from "vue";
import { supabase } from "../../lib/supabase";

const STORAGE_BUCKET = "portfolio-assets";

const loading = ref(true);
const saving = ref(false);
const error = ref("");
const success = ref("");

const profileId = ref(null);
const form = ref(blankForm());

const selectedFile = ref(null);
const previewUrl = ref("");
const originalAvatarUrl = ref("");

function blankForm() {
  return {
    display_name: "",
    headline: "",
    bio: "",
    avatar_url: "",
    location: "",
    email: "",
    seo_title: "",
    seo_description: "",
  };
}

function clearImageSelection() {
  if (previewUrl.value.startsWith("blob:")) {
    URL.revokeObjectURL(previewUrl.value);
  }

  previewUrl.value = "";
  selectedFile.value = null;
}

function handleFileChange(event) {
  clearImageSelection();
  error.value = "";
  success.value = "";

  const file = event.target.files?.[0];
  if (!file) return;

  const allowedTypes = ["image/jpeg", "image/png", "image/webp"];

  if (!allowedTypes.includes(file.type)) {
    error.value = "Foto harus berformat JPG, PNG, atau WebP.";
    event.target.value = "";
    return;
  }

  if (file.size > 2 * 1024 * 1024) {
    error.value = "Ukuran foto maksimal 2 MB.";
    event.target.value = "";
    return;
  }

  selectedFile.value = file;
  previewUrl.value = URL.createObjectURL(file);
}

function getStoragePath(url) {
  if (!url) return null;

  try {
    const parsed = new URL(url);
    const marker = `/storage/v1/object/public/${STORAGE_BUCKET}/`;
    const index = parsed.pathname.indexOf(marker);

    if (index === -1) return null;

    return decodeURIComponent(parsed.pathname.slice(index + marker.length));
  } catch {
    return null;
  }
}

async function uploadAvatar(file) {
  const { data: authData, error: authError } = await supabase.auth.getUser();

  if (authError || !authData.user) {
    throw new Error("Sesi login berakhir. Silakan login kembali.");
  }

  const extensions = {
    "image/jpeg": "jpg",
    "image/png": "png",
    "image/webp": "webp",
  };

  const path = `${authData.user.id}/${crypto.randomUUID()}.${extensions[file.type]}`;

  const { error: uploadError } = await supabase.storage
    .from(STORAGE_BUCKET)
    .upload(path, file, {
      contentType: file.type,
      cacheControl: "3600",
      upsert: false,
    });

  if (uploadError) throw uploadError;

  const { data } = supabase.storage.from(STORAGE_BUCKET).getPublicUrl(path);

  return { path, url: data.publicUrl };
}

async function removeAvatar(url) {
  const path = getStoragePath(url);
  if (!path) return;

  const { error: removeError } = await supabase.storage
    .from(STORAGE_BUCKET)
    .remove([path]);

  if (removeError) {
    console.error("Gagal menghapus foto lama:", removeError.message);
  }
}

async function loadProfile() {
  loading.value = true;
  error.value = "";

  try {
    const { data, error: queryError } = await supabase
      .from("site_profile")
      .select(
        "id, display_name, headline, bio, avatar_url, location, email, seo_title, seo_description",
      )
      .limit(2);

    if (queryError) throw queryError;

    if (!data || data.length === 0) {
      throw new Error(
        "Data profil belum tersedia. Buat satu baris profil di tabel site_profile terlebih dahulu.",
      );
    }

    if (data.length > 1) {
      throw new Error(
        "Tabel site_profile memiliki lebih dari satu baris. Pastikan hanya ada satu profil utama.",
      );
    }

    const profile = data[0];

    profileId.value = profile.id;
    form.value = {
      display_name: profile.display_name || "",
      headline: profile.headline || "",
      bio: profile.bio || "",
      avatar_url: profile.avatar_url || "",
      location: profile.location || "",
      email: profile.email || "",
      seo_title: profile.seo_title || "",
      seo_description: profile.seo_description || "",
    };

    originalAvatarUrl.value = profile.avatar_url || "";
  } catch (err) {
    console.error("Gagal memuat profil:", err);
    error.value = err.message || "Gagal memuat data profil.";
  } finally {
    loading.value = false;
  }
}

async function saveProfile() {
  error.value = "";
  success.value = "";

  if (!profileId.value) {
    error.value = "ID profil tidak ditemukan. Muat ulang halaman.";
    return;
  }

  if (!form.value.display_name.trim()) {
    error.value = "Nama tampilan wajib diisi.";
    return;
  }

  saving.value = true;
  let uploadedPath = null;

  try {
    let avatarUrl = form.value.avatar_url.trim() || null;

    if (selectedFile.value) {
      const uploaded = await uploadAvatar(selectedFile.value);
      uploadedPath = uploaded.path;
      avatarUrl = uploaded.url;
    }

    const payload = {
      display_name: form.value.display_name.trim(),
      headline: form.value.headline.trim() || null,
      bio: form.value.bio.trim() || null,
      avatar_url: avatarUrl,
      location: form.value.location.trim() || null,
      email: form.value.email.trim() || null,
      seo_title: form.value.seo_title.trim() || null,
      seo_description: form.value.seo_description.trim() || null,
      updated_at: new Date().toISOString(),
    };

    const { error: updateError } = await supabase
      .from("site_profile")
      .update(payload)
      .eq("id", profileId.value);

    if (updateError) throw updateError;

    if (
      selectedFile.value &&
      originalAvatarUrl.value &&
      originalAvatarUrl.value !== avatarUrl
    ) {
      await removeAvatar(originalAvatarUrl.value);
    }

    form.value.avatar_url = avatarUrl || "";
    originalAvatarUrl.value = avatarUrl || "";
    clearImageSelection();

    success.value = "Profil berhasil diperbarui.";
  } catch (err) {
    if (uploadedPath) {
      const { error: cleanupError } = await supabase.storage
        .from(STORAGE_BUCKET)
        .remove([uploadedPath]);

      if (cleanupError) {
        console.error("Pembersihan upload gagal:", cleanupError.message);
      }
    }

    console.error("Gagal menyimpan profil:", err);
    error.value = err.message || "Gagal menyimpan profil.";
  } finally {
    saving.value = false;
  }
}

onMounted(loadProfile);
onBeforeUnmount(clearImageSelection);
</script>

<template>
  <div class="mb-4">
    <p class="eyebrow mb-2">CONTENT / PROFILE</p>
    <h1 class="h2 fw-bold mb-1">Manajemen Profil</h1>
    <p class="text-muted-custom mb-0">
      Kelola identitas, informasi kontak, foto, dan SEO portfolio.
    </p>
  </div>

  <div
    v-if="error"
    class="alert alert-danger py-2"
  >
    <i class="bi bi-exclamation-circle me-2"></i>
    {{ error }}
    <button
      type="button"
      class="btn btn-sm btn-outline-danger ms-2"
      @click="loadProfile"
      :disabled="loading || saving"
    >
      Coba lagi
    </button>
  </div>

  <div
    v-if="success"
    class="alert-app mb-3"
  >
    <i class="bi bi-check-circle me-2"></i>
    {{ success }}
  </div>

  <div
    v-if="loading"
    class="panel p-5 text-center"
  >
    <div
      class="spinner-border text-accent mb-3"
      role="status"
    ></div>
    <p class="text-muted-custom mb-0">Memuat informasi profil...</p>
  </div>

  <form
    v-else
    @submit.prevent="saveProfile"
  >
    <div class="row g-4">
      <div class="col-12 col-xl-8">
        <section class="panel p-4 mb-4">
          <p class="eyebrow mb-2">PERSONAL INFORMATION</p>
          <h2 class="h5 fw-bold mb-4">Informasi utama</h2>

          <div class="mb-3">
            <label class="form-label small">Nama tampilan *</label>
            <input
              v-model="form.display_name"
              class="form-control"
              maxlength="160"
              required
              placeholder="Nama yang tampil di portfolio"
            />
          </div>

          <div class="mb-3">
            <label class="form-label small">Headline / profesi</label>
            <input
              v-model="form.headline"
              class="form-control"
              maxlength="300"
              placeholder="Contoh: Web Developer & UI Designer"
            />
          </div>

          <div class="mb-3">
            <label class="form-label small">Bio</label>
            <textarea
              v-model="form.bio"
              class="form-control"
              rows="5"
              placeholder="Ceritakan tentang diri, keahlian, dan pengalamanmu."
            ></textarea>
          </div>

          <div class="row g-3">
            <div class="col-md-6">
              <label class="form-label small">Lokasi</label>
              <input
                v-model="form.location"
                class="form-control"
                maxlength="200"
                placeholder="Kota, negara"
              />
            </div>

            <div class="col-md-6">
              <label class="form-label small">Email kontak</label>
              <input
                v-model="form.email"
                class="form-control"
                type="email"
                maxlength="254"
                placeholder="email@example.com"
              />
            </div>
          </div>
        </section>

        <section class="panel p-4 mb-4">
          <p class="eyebrow mb-2">SEARCH ENGINE OPTIMIZATION</p>
          <h2 class="h5 fw-bold mb-4">Pengaturan SEO</h2>

          <div class="mb-3">
            <label class="form-label small">Judul SEO</label>
            <input
              v-model="form.seo_title"
              class="form-control"
              maxlength="300"
              placeholder="Nama | Web Developer"
            />
            <div class="form-text text-muted-custom">
              Judul yang digunakan sebagai identitas halaman di mesin pencari.
            </div>
          </div>

          <div>
            <label class="form-label small">Deskripsi SEO</label>
            <textarea
              v-model="form.seo_description"
              class="form-control"
              rows="3"
              maxlength="500"
              placeholder="Deskripsi singkat tentang portfolio."
            ></textarea>
            <div class="form-text text-muted-custom">
              {{ form.seo_description.length }}/500 karakter
            </div>
          </div>
        </section>
      </div>

      <div class="col-12 col-xl-4">
        <section class="panel p-4 mb-4">
          <p class="eyebrow mb-2">PROFILE IMAGE</p>
          <h2 class="h5 fw-bold mb-3">Foto profil</h2>

          <div class="text-center mb-4">
            <img
              v-if="previewUrl || form.avatar_url"
              :src="previewUrl || form.avatar_url"
              :alt="form.display_name || 'Foto profil'"
              class="rounded-circle border"
              style="width: 160px; height: 160px; object-fit: cover"
            />

            <div
              v-else
              class="rounded-circle d-flex align-items-center justify-content-center mx-auto"
              style="
                width: 160px;
                height: 160px;
                background: var(--surface-2, #252a32);
              "
            >
              <i class="bi bi-person fs-1 text-secondary"></i>
            </div>
          </div>

          <label class="form-label small">Pilih foto baru</label>
          <input
            type="file"
            class="form-control"
            accept="image/jpeg,image/png,image/webp"
            @change="handleFileChange"
          />

          <p class="text-muted-custom small mt-2 mb-0">
            Format JPG, PNG, WebP. Maksimal 2 MB.
          </p>
        </section>

        <section class="panel p-4">
          <p class="eyebrow mb-2">SAVE CHANGES</p>
          <h2 class="h5 fw-bold mb-2">Simpan profil</h2>
          <p class="text-muted-custom small mb-3">
            Perubahan akan disimpan ke Supabase.
          </p>

          <button
            type="submit"
            class="btn btn-accent w-100"
            :disabled="saving || !profileId"
          >
            <span
              v-if="saving"
              class="spinner-border spinner-border-sm me-2"
              role="status"
            ></span>
            <i
              v-else
              class="bi bi-check2-circle me-2"
            ></i>
            {{ saving ? "Menyimpan..." : "Simpan perubahan" }}
          </button>

          <button
            type="button"
            class="btn btn-outline-soft w-100 mt-2"
            :disabled="saving"
            @click="loadProfile"
          >
            Muat ulang data
          </button>
        </section>
      </div>
    </div>
  </form>
</template>
